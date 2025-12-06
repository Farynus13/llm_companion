#include <jni.h>
#include <string>
#include <vector>
#include <cstring>
#include <android/log.h>
#include "llama.cpp/include/llama.h"

#define TAG "LLM_Native"

// Global variables
static llama_model* model = nullptr;
static llama_context* ctx = nullptr;

// --- HELPERS (Manual implementation of missing functions) ---

// Helper to clear the batch
static void batch_clear(struct llama_batch & batch) {
    batch.n_tokens = 0;
}

// Helper to add a token to the batch
static void batch_add(struct llama_batch & batch, llama_token id, llama_pos pos, int32_t seq_id, bool logits) {
    batch.token   [batch.n_tokens] = id;
    batch.pos     [batch.n_tokens] = pos;
    batch.n_seq_id[batch.n_tokens] = 1; // We only use 1 sequence ID per token
    batch.seq_id  [batch.n_tokens][0] = seq_id;
    batch.logits  [batch.n_tokens] = logits ? 1 : 0;
    
    batch.n_tokens++;
}
// -----------------------------------------------------------

extern "C" {

    // 1. Load the Model
    __attribute__((visibility("default"))) __attribute__((used))
    int load_model(const char* model_path) {
        if (model) {
            llama_free_model(model);
            model = nullptr;
        }
        if (ctx) {
            llama_free(ctx);
            ctx = nullptr;
        }

        llama_backend_init();

        llama_model_params model_params = llama_model_default_params();
        model = llama_load_model_from_file(model_path, model_params);
        
        if (!model) {
            __android_log_print(ANDROID_LOG_ERROR, TAG, "Failed to load model: %s", model_path);
            return -1;
        }

        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 2048;
        ctx_params.n_threads = 4; // Adjust based on phone power
        
        ctx = llama_new_context_with_model(model, ctx_params);
        if (!ctx) {
            __android_log_print(ANDROID_LOG_ERROR, TAG, "Failed to create context");
            return -1;
        }

        return 0;
    }

// 2. Generate Text (Aggressive Stop Version)
    __attribute__((visibility("default"))) __attribute__((used))
    char* completion(const char* text, const char* stop_token) {
        if (!ctx) return strdup("Error: Model not loaded");
        
        // Clear previous cache
        llama_kv_cache_clear(ctx);
        
        // Convert stop_token to std::string for easier checking
        std::string stop_sequence(stop_token);

        // -- Tokenize --
        std::string prompt(text);
        std::vector<llama_token> tokens_list;
        tokens_list.resize(prompt.size() + 32);
        
        int n_tokens = llama_tokenize(model, prompt.c_str(), prompt.length(), tokens_list.data(), tokens_list.size(), true, false);
        if (n_tokens < 0) {
            tokens_list.resize(-n_tokens);
            n_tokens = llama_tokenize(model, prompt.c_str(), prompt.length(), tokens_list.data(), tokens_list.size(), true, false);
        }
        tokens_list.resize(n_tokens);

        // -- Batch Setup --
        llama_batch batch = llama_batch_init(512, 0, 1);
        for (size_t i = 0; i < tokens_list.size(); i++) {
            batch_add(batch, tokens_list[i], i, 0, (i == tokens_list.size() - 1));
        }

        if (llama_decode(ctx, batch) != 0) {
            llama_batch_free(batch);
            return strdup("Error: Decode failed");
        }

        // -- Generate Loop --
        std::string result = "";
        int n_predict = 1000; 

        for (int i = 0; i < n_predict; i++) {
            auto* logits = llama_get_logits_ith(ctx, batch.n_tokens - 1);
            int n_vocab = llama_n_vocab(model);

            // Greedy Sampling
            llama_token new_token_id = 0;
            float max_prob = -1e9;
            for (int k = 0; k < n_vocab; k++) {
                if (logits[k] > max_prob) {
                    max_prob = logits[k];
                    new_token_id = k;
                }
            }

            if (llama_token_is_eog(model, new_token_id)) {
                break;
            }

            char buf[256];
            int n = llama_token_to_piece(model, new_token_id, buf, sizeof(buf), 0, true);
            
            if (n > 0) {
                std::string piece(buf, n);
                result += piece;
            }

            // --- DYNAMIC STOP LOGIC ---
            size_t stop_pos;
            
            // 1. Check the DYNAMIC stop token passed from Dart
            stop_pos = result.find(stop_sequence);
            if (stop_pos != std::string::npos) {
                result = result.substr(0, stop_pos);
                break; // STOP
            }

            // 2. Keep Universal Hallucination Checks (Safety net)
            // Even if using TinyLlama, we don't want it impersonating the user
            if (result.find("<|im_start|>") != std::string::npos || 
                result.find("<|user|>") != std::string::npos ||
                result.find("### Instruction:") != std::string::npos) {
                break;
            }
            // ---------------------------

            batch_clear(batch);
            batch_add(batch, new_token_id, n_tokens + i, 0, true);

            if (llama_decode(ctx, batch) != 0) {
                break;
            }
        }

        llama_batch_free(batch);
        return strdup(result.c_str());
    }
}