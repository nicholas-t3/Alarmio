//
//  AlarmConfiguration+Display.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/13/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

// MARK: - VoicePersona Display

extension VoicePersona {

    /// Short display name shown in summary rows and selection lists.
    var displayName: String {
        switch self {
        case .darkSpaceLord: return "Dark Space Lord"
        case .drillSergeant: return "Drill Sergeant"
        case .asmrWhisper: return "ASMR Whisper"
        case .strongAussie: return "Strong Aussie"
        case .playfulFemmeFatale: return "Femme Fatale"
        case .princeOfTheNorth: return "Prince of the North"
        case .movieTrailer: return "Movie Trailer"
        case .theBro: return "The Bro"
        case .rythmicSinger: return "Rythmic Singer"
        case .theDad: return "The Dad"
        case .meditationGuru: return "Meditation Guru"
        case .smoothBoyfriend: return "Smooth Boyfriend"
        case .soothingSarah: return "Soothing Sarah"
        case .reptilianMonster: return "Reptilian Monster"
        }
    }

    /// Two-word vibe descriptor — e.g. "Soothing · Gentle".
    /// Used everywhere a one-line subtitle is needed.
    var descriptor: String {
        switch self {
        case .darkSpaceLord: return "Dramatic · Commanding"
        case .drillSergeant: return "Firm · Unrelenting"
        case .asmrWhisper: return "Soft · Tingly"
        case .strongAussie: return "Warm · Laid-Back"
        case .playfulFemmeFatale: return "Flirty · Mischievous"
        case .princeOfTheNorth: return "Noble · Regal"
        case .movieTrailer: return "Epic · Cinematic"
        case .theBro: return "Casual · Vibes"
        case .rythmicSinger: return "Melodic · Breezy"
        case .theDad: return "Caring · Grounded"
        case .meditationGuru: return "Calm · Grounded"
        case .smoothBoyfriend: return "Tender · Confident"
        case .soothingSarah: return "Gentle · Reassuring"
        case .reptilianMonster: return "Unsettling · Hissing"
        }
    }

    /// SF Symbol icon used in row and pill UIs.
    var icon: String {
        switch self {
        case .darkSpaceLord: return "moon.stars.fill"
        case .drillSergeant: return "figure.strengthtraining.traditional"
        case .asmrWhisper: return "waveform.path"
        case .strongAussie: return "sun.max.fill"
        case .playfulFemmeFatale: return "heart.fill"
        case .princeOfTheNorth: return "crown.fill"
        case .movieTrailer: return "film.fill"
        case .theBro: return "hand.wave.fill"
        case .rythmicSinger: return "music.note"
        case .theDad: return "figure.and.child.holdinghands"
        case .meditationGuru: return "leaf.fill"
        case .smoothBoyfriend: return "sparkles"
        case .soothingSarah: return "cloud.fill"
        case .reptilianMonster: return "ant.fill"
        }
    }

    /// Loading-line shown during alarm generation — in-character for each voice.
    var loadingMessage: String {
        switch self {
        case .darkSpaceLord: return "Summoning the dark lord"
        case .drillSergeant: return "Calling the drill sergeant"
        case .asmrWhisper: return "Softening the whisper"
        case .strongAussie: return "Waking up the Aussie"
        case .playfulFemmeFatale: return "Setting the stage for her entrance"
        case .princeOfTheNorth: return "Summoning the prince"
        case .movieTrailer: return "Rolling the trailer"
        case .theBro: return "Grabbing the bro"
        case .rythmicSinger: return "Warming up the singer"
        case .theDad: return "Waking up the dad"
        case .meditationGuru: return "Centering the guru"
        case .smoothBoyfriend: return "Charming up the boyfriend"
        case .soothingSarah: return "Calling Sarah over"
        case .reptilianMonster: return "Awakening the monster"
        }
    }
}

// MARK: - AlarmTone Display

extension AlarmTone {

    var displayName: String {
        switch self {
        case .calm: return "Calm"
        case .encourage: return "Encourage"
        case .push: return "Push"
        case .strict: return "Strict"
        case .fun: return "Fun"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .calm: return "leaf.fill"
        case .encourage: return "hand.thumbsup.fill"
        case .push: return "bolt.fill"
        case .strict: return "exclamationmark.triangle.fill"
        case .fun: return "face.smiling.fill"
        case .other: return "sparkles"
        }
    }
}

// MARK: - AlarmIntensity Display

extension AlarmIntensity {

    var displayName: String {
        switch self {
        case .gentle: return "Gentle"
        case .balanced: return "Balanced"
        case .intense: return "Intense"
        }
    }

    var icon: String {
        switch self {
        case .gentle: return "leaf"
        case .balanced: return "circle.grid.2x2"
        case .intense: return "bolt.fill"
        }
    }
}

// MARK: - WhyContext Display

extension WhyContext {

    var displayName: String {
        switch self {
        case .work: return "Work"
        case .school: return "School"
        case .gym: return "Gym"
        case .family: return "Family"
        case .personalGoal: return "Goal"
        case .important: return "Important"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .school: return "book.fill"
        case .gym: return "dumbbell.fill"
        case .family: return "house.fill"
        case .personalGoal: return "star.fill"
        case .important: return "exclamationmark.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}
