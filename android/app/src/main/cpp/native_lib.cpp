#include <jni.h>
#include <string>
#include <vector>
#include <cstring>
#include <android/log.h>
#include "llama.cpp/include/llama.h"

#define TAG "LLM_Native"

// Defines a pointer to a function that takes a string and returns void
typedef void (*CallbackFunc)(const char* token);

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
// Helper: Checks if the end of 'buffer' matches the beginning of 'stop'
// e.g. buffer="abc <|im", stop="<|im_end|>" -> Returns TRUE
bool is_partial_match(const std::string& buffer, const std::string& stop) {
    if (buffer.empty() || stop.empty()) return false;
    
    // We check overlaps from length 1 up to length - 1
    // (If it matched the full length, the main loop would have caught it already)
    size_t check_len = std::min(buffer.length(), stop.length() - 1);
    
    for (size_t len = check_len; len > 0; len--) {
        // Get the tail of the buffer
        std::string tail = buffer.substr(buffer.length() - len);
        // Get the head of the stop word
        std::string head = stop.substr(0, len);
        
        if (tail == head) return true;
    }
    return false;
}

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

    __attribute__((visibility("default"))) __attribute__((used))
    void completion(const char* text, const char* stop_token, CallbackFunc callback) {
        if (!ctx) { callback("Error: Model not loaded"); return; }
        llama_kv_cache_clear(ctx);

        std::string stop_sequence(stop_token);
        std::string prompt(text);
        
        // Define all stop words
        std::vector<std::string> stops;
        stops.push_back(stop_sequence);       // Dynamic (from Dart)
        stops.push_back("<|im_end|>");        // Qwen
        stops.push_back("<|user|>");          // Safety
        stops.push_back("<|im_start|>");      // Safety
        stops.push_back("</s>");              // Llama

        // --- TOKENIZE ---
        std::vector<llama_token> tokens_list;
        tokens_list.resize(prompt.size() + 32);
        int n_tokens = llama_tokenize(model, prompt.c_str(), prompt.length(), tokens_list.data(), tokens_list.size(), true, false);
        if (n_tokens < 0) {
            tokens_list.resize(-n_tokens);
            n_tokens = llama_tokenize(model, prompt.c_str(), prompt.length(), tokens_list.data(), tokens_list.size(), true, false);
        }
        tokens_list.resize(n_tokens);

        llama_batch batch = llama_batch_init(4096, 0, 1);
        for (size_t i = 0; i < tokens_list.size(); i++) {
            batch_add(batch, tokens_list[i], i, 0, (i == tokens_list.size() - 1));
        }

        if (llama_decode(ctx, batch) != 0) {
            llama_batch_free(batch);
            callback("Error: Decode failed");
            return;
        }

        // --- GENERATION LOOP ---
        int n_predict = 400; 
        std::string pending_buffer = "";

        for (int i = 0; i < n_predict; i++) {
            auto* logits = llama_get_logits_ith(ctx, batch.n_tokens - 1);
            if (logits == nullptr) break;

            int n_vocab = llama_n_vocab(model);
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
                pending_buffer += piece;

                // 1. CHECK FULL MATCH (Stop Immediately)
                bool stop_hit = false;
                for (const auto& s : stops) {
                    size_t pos = pending_buffer.find(s);
                    if (pos != std::string::npos) {
                        // Flush safe part
                        std::string safe = pending_buffer.substr(0, pos);
                        if (!safe.empty()) callback(safe.c_str());
                        stop_hit = true;
                        break;
                    }
                }
                if (stop_hit) break; // EXIT LOOP

                // 2. CHECK PARTIAL MATCH (Hold data if suspicious)
                bool suspicious = false;
                for (const auto& s : stops) {
                    if (is_partial_match(pending_buffer, s)) {
                        suspicious = true;
                        break;
                    }
                }

                // 3. FLUSH LOGIC
                if (!suspicious) {
                    // Safe to print everything!
                    callback(pending_buffer.c_str());
                    pending_buffer = "";
                } else {
                    // Suspicious! Hold the buffer. 
                    // But if buffer gets HUGE (e.g. 50 chars), it's probably a false alarm.
                    // We flush the start to keep UI responsive.
                    if (pending_buffer.length() > 20) {
                        // Keep last 10 chars, flush the rest
                        size_t keep = 10; 
                        size_t flush_len = pending_buffer.length() - keep;
                        std::string chunk = pending_buffer.substr(0, flush_len);
                        callback(chunk.c_str());
                        pending_buffer = pending_buffer.substr(flush_len);
                    }
                }
            }

            batch_clear(batch);
            batch_add(batch, new_token_id, n_tokens + i, 0, true);

            if (llama_decode(ctx, batch) != 0) {
                break;
            }
        }
        
        // Final Flush (if anything left)
        if (!pending_buffer.empty()) {
            // Re-check one last time to be sure no stop token is hiding
            bool stop_hit = false;
            for (const auto& s : stops) {
                 if (pending_buffer.find(s) != std::string::npos) {
                     stop_hit = true; break;
                 }
            }
            if (!stop_hit) callback(pending_buffer.c_str());
        }

        llama_batch_free(batch);
    }
}