// generate-desktop-samples.mjs
//
// One-off: generate a single shared script across all 14 voices and drop
// the MP3s on the user's Desktop for apples-to-apples comparison.
//
// Usage:
//   ELEVENLABS_API_KEY=sk_... node scripts/generate-desktop-samples.mjs

import { mkdir, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { join } from "node:path";

const MODEL_ID = "eleven_flash_v2_5";
const LINE = "It's nice and early; it's 7 a.m., time to get up.";

const VOICE_SETTINGS = {
    stability: 0.5,
    similarity_boost: 0.75,
    style: 0.0,
    use_speaker_boost: true,
};

const OUTPUT_DIR = join(homedir(), "Desktop", "Alarmio-Voice-Samples");

const VOICES = [
    { key: "dark_space_lord",      name: "Dark Space Lord",      voiceId: "92UhynWV7XlK7tHYCFoc" },
    { key: "drill_sergeant",       name: "Drill Sergeant",       voiceId: "08sPZLkzrRgqRAHVLrCW" },
    { key: "asmr_whisper",         name: "ASMR Whisper",         voiceId: "nbk2esDn4RRk4cVDdoiE" },
    { key: "strong_aussie",        name: "Strong Aussie",        voiceId: "YLbQE9U7P1K6rBNJWNSv" },
    { key: "playful_femme_fatale", name: "Playful Femme Fatale", voiceId: "eVItLK1UvXctxuaRV2Oq" },
    { key: "prince_of_the_north",  name: "Prince of the North",  voiceId: "wo6udizrrtpIxWGp2qJk" },
    { key: "movie_trailer",        name: "Movie Trailer",        voiceId: "uOhSc7VJxlMhOwVsIJap" },
    { key: "the_bro",              name: "The Bro",              voiceId: "eadgjmk4R4uojdsheG9t" },
    { key: "rythmic_singer",       name: "Rythmic Singer",       voiceId: "ui0NMIinCTg8KvB4ogeV" },
    { key: "the_dad",              name: "The Dad",              voiceId: "XmUeU0FRyne67Dy7UaT4" },
    { key: "meditation_guru",      name: "Meditation Guru",      voiceId: "6bPfTtSpgxgD0GeBVfqu" },
    { key: "smooth_boyfriend",     name: "Smooth Boyfriend",     voiceId: "zO2z8i0srbO9r7GT5C4h" },
    { key: "soothing_sarah",       name: "Soothing Sarah",       voiceId: "bIQlQ61Q7WgbyZAL7IWj" },
    { key: "reptilian_monster",    name: "Reptilian Monster",    voiceId: "xYWUvKNK6zWCgsdAK7Wi" },
];

async function synthesize(voice, apiKey) {
    const res = await fetch(
        `https://api.elevenlabs.io/v1/text-to-speech/${voice.voiceId}`,
        {
            method: "POST",
            headers: {
                "content-type": "application/json",
                "xi-api-key": apiKey,
                "accept": "audio/mpeg",
            },
            body: JSON.stringify({
                text: LINE,
                model_id: MODEL_ID,
                voice_settings: VOICE_SETTINGS,
            }),
        },
    );
    if (!res.ok) {
        const body = await res.text();
        throw new Error(
            `ElevenLabs ${res.status} for ${voice.key}: ${body.slice(0, 500)}`,
        );
    }
    return new Uint8Array(await res.arrayBuffer());
}

async function main() {
    const apiKey = process.env.ELEVENLABS_API_KEY;
    if (!apiKey) {
        console.error("ELEVENLABS_API_KEY not set. Export it and re-run.");
        process.exit(1);
    }

    await mkdir(OUTPUT_DIR, { recursive: true });

    console.log(`Model: ${MODEL_ID}`);
    console.log(`Line:  "${LINE}"`);
    console.log(`Output: ${OUTPUT_DIR}`);
    console.log(`Voices: ${VOICES.length}`);
    console.log();

    let succeeded = 0;
    let failed = 0;
    const t0 = Date.now();

    for (const [i, voice] of VOICES.entries()) {
        const tCall = Date.now();
        try {
            const bytes = await synthesize(voice, apiKey);
            // Prefix with index so Finder sorts them deterministically.
            const idx = String(i + 1).padStart(2, "0");
            const filename = `${idx} - ${voice.name}.mp3`;
            const outPath = join(OUTPUT_DIR, filename);
            await writeFile(outPath, bytes);
            const kb = (bytes.byteLength / 1024).toFixed(1);
            const ms = Date.now() - tCall;
            console.log(
                `  ✓ ${filename.padEnd(36)} ${kb.padStart(6)} KB  ${String(ms).padStart(5)}ms`,
            );
            succeeded++;
        } catch (e) {
            console.log(`  ✗ ${voice.name.padEnd(22)} ${e.message}`);
            failed++;
        }
    }

    const totalMs = Date.now() - t0;
    console.log();
    console.log(
        `Done: ${succeeded} succeeded, ${failed} failed in ${totalMs}ms`,
    );
    console.log(`Open in Finder: open "${OUTPUT_DIR}"`);
    if (failed > 0) process.exit(2);
}

await main();
