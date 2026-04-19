//
//  AlarmSchedulerPickSafePreAlertTests.swift
//  AlarmioTests
//
//  Created by Parenthood ApS on 4/19/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Testing
import Foundation
@testable import Alarmio

@MainActor
struct AlarmSchedulerPickSafePreAlertTests {

    // MARK: - Setup

    private func makeScheduler() -> AlarmScheduler {
        AlarmScheduler(audioFileManager: AudioFileManager())
    }

    private func now() -> Date {
        // Fixed reference used only as "now" in these tests — values are
        // all relative so the absolute moment doesn't matter. Pinning it
        // to noon on a weekday keeps intended-fire arithmetic simple.
        var cal = Calendar.current
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: 2026, month: 4, day: 20, hour: 12, minute: 0, second: 0))!
    }

    // MARK: - Tests

    @Test("Full lead fits — repeating tomorrow +23h, 1h desired → 3600s")
    func fullLeadFits() {
        let scheduler = makeScheduler()
        let now = now()
        let intended = now.addingTimeInterval(23 * 3600)  // tomorrow, same clock time -1h
        let result = scheduler.pickSafePreAlert(
            intendedFireDate: intended,
            desired: 3600,
            isRepeating: true,
            now: now
        )
        #expect(result == 3600)
    }

    @Test("Headroom < desired, repeating — fires in 30min, 1h desired → 29min")
    func clampedByHeadroomRepeating() {
        let scheduler = makeScheduler()
        let now = now()
        let intended = now.addingTimeInterval(30 * 60)  // 30min out
        let result = scheduler.pickSafePreAlert(
            intendedFireDate: intended,
            desired: 3600,
            isRepeating: true,
            now: now
        )
        // Minute-aligned, must leave ≥ 60s buffer. 30min - 60s = 29min.
        #expect(result == 29 * 60)
    }

    @Test("Headroom < 1 minute — falls through to 0")
    func headroomTooShort() {
        let scheduler = makeScheduler()
        let now = now()
        let intended = now.addingTimeInterval(45)  // 45s out
        let result = scheduler.pickSafePreAlert(
            intendedFireDate: intended,
            desired: 3600,
            isRepeating: true,
            now: now
        )
        #expect(result == 0)
    }

    @Test("Lead disabled — desired 0 returns 0 regardless of headroom")
    func leadDisabled() {
        let scheduler = makeScheduler()
        let now = now()
        let intended = now.addingTimeInterval(3600)
        let result = scheduler.pickSafePreAlert(
            intendedFireDate: intended,
            desired: 0,
            isRepeating: true,
            now: now
        )
        #expect(result == 0)
    }

    @Test("Exact minute-boundary fit — +61min, 1h desired → 3600s")
    func exactMinuteBoundary() {
        let scheduler = makeScheduler()
        let now = now()
        let intended = now.addingTimeInterval(61 * 60)  // 61min out
        let result = scheduler.pickSafePreAlert(
            intendedFireDate: intended,
            desired: 3600,
            isRepeating: true,
            now: now
        )
        // Shifted time = intended - 3600 = now + 60s. Exactly on the 60s
        // buffer boundary — passes (>=).
        #expect(result == 3600)
    }

    @Test("One second short of full lead — walks down one minute")
    func oneSecondShort() {
        let scheduler = makeScheduler()
        let now = now()
        let intended = now.addingTimeInterval(60 * 60 + 59)  // 59min59s out (1s short of 1h)
        let result = scheduler.pickSafePreAlert(
            intendedFireDate: intended,
            desired: 3600,
            isRepeating: true,
            now: now
        )
        // Can't fit 3600 (shifted would be now+59s, fails buffer).
        // Walks to 3540 — shifted = now + 59*60+59s - 3540 = now + 119s. Passes.
        #expect(result == 59 * 60)
    }

    @Test("Would cross midnight — 9h lead at 07:00 → walks down until same-day")
    func crossMidnightRepeating() {
        let scheduler = makeScheduler()
        // "now" is at 12:00 on day N. intended = 07:00 on day N+1 (19h out).
        // 9h lead would shift registered time to 22:00 on day N — crosses
        // midnight relative to the intended day (N+1), so rejected.
        // Walks down by 60s until shifted time is on day N+1 → 07:00 exactly
        // means shift 0, so the loop exits at candidate = 60 and walks up to…
        // wait: the loop rejects any candidate where shifted < start-of-intended-day.
        // Earliest shift that keeps shifted on day N+1 is the one that lands
        // shifted at midnight (00:00) of day N+1 → 7h exactly (25200s).
        let now = now()  // day N at 12:00
        let cal = Calendar.current
        let intended = cal.date(byAdding: .hour, value: 19, to: now)!  // day N+1 at 07:00

        let result = scheduler.pickSafePreAlert(
            intendedFireDate: intended,
            desired: 9 * 3600,
            isRepeating: true,
            now: now
        )
        // Largest same-day-safe value is 7h (shifted lands exactly at 00:00
        // of day N+1 which is startOfDay(intended) — passes sameDay check).
        #expect(result == 7 * 3600)
    }

    @Test(".fixed tolerates cross-day — full lead granted")
    func fixedAllowsCrossDay() {
        let scheduler = makeScheduler()
        // Same setup as crossMidnightRepeating but isRepeating = false.
        let now = now()
        let cal = Calendar.current
        let intended = cal.date(byAdding: .hour, value: 19, to: now)!

        let result = scheduler.pickSafePreAlert(
            intendedFireDate: intended,
            desired: 9 * 3600,
            isRepeating: false,
            now: now
        )
        // .fixed doesn't need same-day constraint — full 9h granted.
        #expect(result == 9 * 3600)
    }

    @Test("Minute alignment — desired 3599s (one second under 1h) → 59min")
    func minuteAlignedFloor() {
        let scheduler = makeScheduler()
        let now = now()
        let intended = now.addingTimeInterval(23 * 3600)  // plenty of headroom
        let result = scheduler.pickSafePreAlert(
            intendedFireDate: intended,
            desired: 3599,  // 1s under 1h
            isRepeating: true,
            now: now
        )
        // floor(3599/60)*60 = 59*60 = 3540
        #expect(result == 3540)
    }

    // MARK: - buildIntendedFireDate — H4 regression (seconds pinned to 0)

    @Test("buildIntendedFireDate pins seconds to 0 — one-time")
    func intendedFireDateSecondsZeroOneTime() {
        let scheduler = makeScheduler()
        let cal = Calendar.current
        // Reference at HH:MM:27 — without .second = 0, nextDate would
        // produce a date at :27 seconds.
        let ref = cal.date(from: DateComponents(year: 2026, month: 4, day: 20, hour: 10, minute: 28, second: 27))!
        let wake = cal.date(from: DateComponents(hour: 14, minute: 0))
        let config = AlarmConfiguration(wakeTime: wake)
        let intended = scheduler.buildIntendedFireDate(from: config, referenceDate: ref)
        #expect(intended != nil)
        if let intended {
            #expect(cal.component(.second, from: intended) == 0)
        }
    }

    @Test("buildIntendedFireDate pins seconds to 0 — repeating")
    func intendedFireDateSecondsZeroRepeating() {
        let scheduler = makeScheduler()
        let cal = Calendar.current
        let ref = cal.date(from: DateComponents(year: 2026, month: 4, day: 20, hour: 10, minute: 28, second: 27))!
        let wake = cal.date(from: DateComponents(hour: 7, minute: 0))
        let config = AlarmConfiguration(wakeTime: wake, repeatDays: [1, 2, 3, 4, 5])
        let intended = scheduler.buildIntendedFireDate(from: config, referenceDate: ref)
        #expect(intended != nil)
        if let intended {
            #expect(cal.component(.second, from: intended) == 0)
        }
    }
}
