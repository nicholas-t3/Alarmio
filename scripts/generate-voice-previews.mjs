// generate-voice-previews.mjs
//
// One-shot audition tool for the Alarmio voice catalog.
// Generates one ~10-second MP3 per voice using ElevenLabs, writes to the
// iOS app's bundled VoicePreviews folder. Run this BEFORE committing to
// a TTS model — change MODEL_ID below to switch Flash/Turbo.
//
// Usage:
//   ELEVENLABS_API_KEY=sk_... node scripts/generate-voice-previews.mjs
//
// Re-running overwrites existing files.

import { mkdir, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const MODEL_ID = "eleven_flash_v2_5";
// Switch to "eleven_turbo_v2_5" if Flash quality is insufficient.

const VOICE_SETTINGS = {
    stability: 0.5,
    similarity_boost: 0.75,
    style: 0.0,
    use_speaker_boost: true,
};

const OUTPUT_DIR = new URL(
    "../alarmio-ios/Alarmio/Alarmio/Resources/VoicePreviews/",
    import.meta.url,
);

const VOICES = [
    {
        key: "dark_space_lord",
        displayName: "Dark Space Lord",
        voiceId: "92UhynWV7XlK7tHYCFoc",
        line: "You cannot escape the morning. The empire rises… and so will you.",
    },
    {
        key: "drill_sergeant",
        displayName: "Drill Sergeant",
        voiceId: "08sPZLkzrRgqRAHVLrCW",
        line: "On your feet, recruit! The day doesn't wait. Move, move, move!",
    },
    {
        key: "asmr_whisper",
        displayName: "ASMR Whisper",
        voiceId: "nbk2esDn4RRk4cVDdoiE",
        line: "Slowly open your eyes… the morning is quiet… and it's just for you.",
    },
    {
        key: "strong_aussie",
        displayName: "Strong Aussie",
        voiceId: "YLbQE9U7P1K6rBNJWNSv",
        line: "Oi, up you get, mate. Sun's out, world's waiting — let's have a crack.",
    },
    {
        key: "playful_femme_fatale",
        displayName: "Playful Femme Fatale",
        voiceId: "eVItLK1UvXctxuaRV2Oq",
        line: "Mmm… the world's been so boring without you awake. Come play.",
    },
    {
        key: "prince_of_the_north",
        displayName: "Prince of the North",
        voiceId: "wo6udizrrtpIxWGp2qJk",
        line: "Rise, my friend. A new day dawns upon the realm — and it belongs to you.",
    },
    {
        key: "movie_trailer",
        displayName: "Movie Trailer Voice",
        voiceId: "uOhSc7VJxlMhOwVsIJap",
        line: "In a world… where every morning matters… one alarm dares to wake you.",
    },
    {
        key: "the_bro",
        displayName: "The Bro",
        voiceId: "eadgjmk4R4uojdsheG9t",
        line: "Yo yo yo, rise and grind dude. Today's gonna be absolutely unreal, let's go.",
    },
    {
        key: "rythmic_singer",
        displayName: "Rythmic Singer",
        voiceId: "ui0NMIinCTg8KvB4ogeV",
        line: "Wake up, wake up, it's a brand new day — singing you out of bed your own way.",
    },
    {
        key: "the_dad",
        displayName: "The Dad",
        voiceId: "XmUeU0FRyne67Dy7UaT4",
        line: "Hey champ, time to get up. I made coffee. Let's make today a good one.",
    },
    {
        key: "meditation_guru",
        displayName: "Meditation Guru",
        voiceId: "6bPfTtSpgxgD0GeBVfqu",
        line: "Breathe in the morning light. Let it fill you. This moment is yours.",
    },
    {
        key: "smooth_boyfriend",
        displayName: "Smooth Boyfriend",
        voiceId: "zO2z8i0srbO9r7GT5C4h",
        line: "Morning, beautiful. I hate to wake you… but today's gonna be ours.",
    },
    {
        key: "soothing_sarah",
        displayName: "Soothing Sarah",
        voiceId: "bIQlQ61Q7WgbyZAL7IWj",
        line: "Good morning, sweetheart. Take your time. The day will wait for you.",
    },
    {
        key: "reptilian_monster",
        displayName: "Reptilian Monster",
        voiceId: "xYWUvKNK6zWCgsdAK7Wi",
        line: "Sssso… you thought you could hide under the covers? I sssee you…",
    },
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
                text: voice.line,
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

    const outDirPath = fileURLToPath(OUTPUT_DIR);
    await mkdir(outDirPath, { recursive: true });

    console.log(`Model: ${MODEL_ID}`);
    console.log(`Output: ${outDirPath}`);
    console.log(`Voices: ${VOICES.length}`);
    console.log();

    let totalChars = 0;
    let succeeded = 0;
    let failed = 0;
    const t0 = Date.now();

    // Sequential to stay well under ElevenLabs concurrency limits and keep
    // error messages legible. 14 calls × ~1s each is fine.
    for (const voice of VOICES) {
        const tCall = Date.now();
        try {
            const bytes = await synthesize(voice, apiKey);
            const outPath = new URL(`./${voice.key}.mp3`, OUTPUT_DIR);
            await writeFile(fileURLToPath(outPath), bytes);
            const kb = (bytes.byteLength / 1024).toFixed(1);
            const ms = Date.now() - tCall;
            console.log(
                `  ✓ ${voice.key.padEnd(22)} ${kb.padStart(6)} KB  ${String(ms).padStart(5)}ms`,
            );
            totalChars += voice.line.length;
            succeeded++;
        } catch (e) {
            console.log(`  ✗ ${voice.key.padEnd(22)} ${e.message}`);
            failed++;
        }
    }

    const totalMs = Date.now() - t0;
    console.log();
    console.log(
        `Done: ${succeeded} succeeded, ${failed} failed, ${totalChars} characters, ${totalMs}ms total`,
    );
    if (failed > 0) process.exit(2);
}

await main();
