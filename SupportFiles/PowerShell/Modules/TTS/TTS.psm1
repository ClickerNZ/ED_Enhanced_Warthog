# Check available voices
Add-Type -TypeDefinition @"
using System;
using System.Speech.Synthesis;
public class TTS {
    public static void GetInstalledVoices() {
        using (var synth = new SpeechSynthesizer()) {
            foreach (var voice in synth.GetInstalledVoices()) {
                Console.WriteLine(voice.VoiceInfo.Name);
            }
        }
    }
}
"@
# USAGE: [TTS]::GetInstalledVoices()

# Speak text using specific voice
Add-Type -TypeDefinition @"
using System;
using System.Speech.Synthesis;
public class TTS {
    public static void SpeakText(string text, string voiceName) {
        using (var synth = new SpeechSynthesizer()) {
            synth.SelectVoice(voiceName);
            synth.Speak(text);
        }
    }
}
"@
# USAGE: [TTS]::SpeakText("Hello, this is a test of the text-to-speech system.", "Microsoft David Desktop")

# Dynamic voice selection
Add-Type -TypeDefinition @"
using System;
using System.Speech.Synthesis;
public class TTS {
    public static void SpeakTextWithSettings(string text, string voiceName, int rate, int volume) {
        using (var synth = new SpeechSynthesizer()) {
            synth.SelectVoice(voiceName);
            synth.Rate = rate; // Rate: -10 (slowest) to 10 (fastest)
            synth.Volume = volume; // Volume: 0 to 100
            synth.Speak(text);
        }
    }
}
"@
# USAGE: [TTS]::SpeakTextWithSettings("Testing different settings for text-to-speech.", "Microsoft Zira Desktop", 2, 90)
