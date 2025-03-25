
# Load the System.Speech assembly explicitly
$assemblyPath = "C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8.1\System.Speech.dll"
Add-Type -Path $assemblyPath
Add-Type -ReferencedAssemblies $assemblyPath -TypeDefinition @"

using System;
using System.Speech.Synthesis;
public class TTS {
    public static void SpeakText(string text, string voiceName = "Microsoft Catherine", int rate = 1, int volume = 100) {		
        using (var synth = new SpeechSynthesizer()) {	
        synth.SelectVoice(voiceName);
        synth.Rate = rate; // Rate: -10 (slowest) to 10 (fastest)
        synth.Volume = volume; // Volume: 0 to 100            
		synth.Speak(text);
        }
    }
}
"@
# USAGE: [TTS]::SpeakText("Testing different settings for text-to-speech.", "Microsoft Zira Desktop", 2, 90)