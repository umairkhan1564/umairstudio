// Runs Whisper (transformers.js) OFF the main thread so long videos don't
// freeze the tab. The page posts PCM audio; we post back progress + chunks.
import { pipeline, env } from 'https://cdn.jsdelivr.net/npm/@xenova/transformers@2.17.2/+esm';
env.allowLocalModels = false;

let transcriber = null;

self.onmessage = async (e) => {
  try {
    if (!transcriber) {
      transcriber = await pipeline('automatic-speech-recognition', 'Xenova/whisper-base', {
        progress_callback: p => { if (p.status === 'progress') self.postMessage({ type: 'model', progress: p.progress || 0 }); }
      });
    }
    self.postMessage({ type: 'transcribing' });
    // WORD-level timestamps so captions line up with the voice exactly
    const out = await transcriber(e.data.pcm, { return_timestamps: 'word', chunk_length_s: 30, stride_length_s: 5 });
    self.postMessage({ type: 'done', chunks: out.chunks || [] });
  } catch (err) {
    self.postMessage({ type: 'error', error: String((err && err.message) || err) });
  }
};
