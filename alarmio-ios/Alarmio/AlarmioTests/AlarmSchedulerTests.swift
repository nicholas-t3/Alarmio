//
//  AlarmSchedulerTests.swift
//  AlarmioTests
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Testing
import AlarmKit
@testable import Alarmio

@MainActor
struct AlarmSchedulerTests {

    // MARK: - Setup

    private func makeScheduler() -> AlarmScheduler {
        AlarmScheduler(audioFileManager: AudioFileManager())
    }

    private func makeConfig(
        hour: Int,
        minute: Int,
        repeatDays: [Int]? = nil,
        tone: AlarmTone? = nil,
        snoozeInterval: Int = 5
    ) -> AlarmConfiguration {
        let cal = Calendar.current
        return AlarmConfiguration(
            wakeTime: cal.date(from: DateComponents(hour: hour, minute: minute)),
            repeatDays: repeatDays,
            tone: tone,
            snoozeInterval: snoozeInterval
        )
    }

    private func makeDate(year: Int = 2026, month: Int = 4, day: Int, hour: Int, minute: Int) -> Date {
        var cal = Calendar.current
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: - One-Time Schedule

    @Test("One-time alarm: future time today fires today")
    func oneTimeFutureToday() {
        let scheduler = makeScheduler()
        // Reference: Thursday April 3, 10:00 AM — alarm at 2:00 PM
        let ref = makeDate(day: 3, hour: 10, minute: 0)
        let config = makeConfig(hour: 14, minute: 0)

        let schedule = scheduler.buildSchedule(from: config, referenceDate: ref)

        if case .fixed(let fireDate) = schedule {
            let cal = Calendar.current
            #expect(cal.component(.hour, from: fireDate) == 14)
            #expect(cal.component(.minute, from: fireDate) == 0)
            #expect(cal.component(.day, from: fireDate) == 3)
        } else {
            Issue.record("Expected .fixed schedule, got \(String(describing: schedule))")
        }
    }

    @Test("One-time alarm: past time today fires tomorrow")
    func oneTimePastToday() {
        let scheduler = makeScheduler()
        // Reference: Thursday April 3, 10:00 AM — alarm at 8:00 AM (already passed)
        let ref = makeDate(day: 3, hour: 10, minute: 0)
        let config = makeConfig(hour: 8, minute: 0)

        let schedule = scheduler.buildSchedule(from: config, referenceDate: ref)

        if case .fixed(let fireDate) = schedule {
            let cal = Calendar.current
            #expect(cal.component(.hour, from: fireDate) == 8)
            #expect(cal.component(.minute, from: fireDate) == 0)
            #expect(cal.component(.day, from: fireDate) == 4) // Tomorrow
        } else {
            Issue.record("Expected .fixed schedule, got \(String(describing: schedule))")
        }
    }

    @Test("One-time alarm: nil wakeTime returns nil")
    func oneTimeNilWakeTime() {
        let scheduler = makeScheduler()
        let config = AlarmConfiguration()

        let schedule = scheduler.buildSchedule(from: config)
        #expect(schedule == nil)
    }

    @Test("One-time alarm: empty repeatDays treated as one-time")
    func emptyRepeatDaysIsOneTime() {
        let scheduler = makeScheduler()
        let ref = makeDate(day: 3, hour: 10, minute: 0)
        let config = makeConfig(hour: 14, minute: 0, repeatDays: [])

        let schedule = scheduler.buildSchedule(from: config, referenceDate: ref)

        if case .fixed = schedule {
            // Correct — treated as one-time
        } else {
            Issue.record("Expected .fixed schedule for empty repeatDays, got \(String(describing: schedule))")
        }
    }

    // MARK: - Repeating Schedule

    @Test("Repeating alarm: weekdays [1,2,3,4,5] maps to Mon-Fri")
    func repeatingWeekdays() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 30, repeatDays: [1, 2, 3, 4, 5])

        let schedule = scheduler.buildSchedule(from: config)

        if case .relative(let relative) = schedule {
            #expect(relative.time.hour == 7)
            #expect(relative.time.minute == 30)
            if case .weekly(let days) = relative.repeats {
                #expect(days.count == 5)
                #expect(days.contains(.monday))
                #expect(days.contains(.tuesday))
                #expect(days.contains(.wednesday))
                #expect(days.contains(.thursday))
                #expect(days.contains(.friday))
                #expect(!days.contains(.saturday))
                #expect(!days.contains(.sunday))
            } else {
                Issue.record("Expected .weekly repeats")
            }
        } else {
            Issue.record("Expected .relative schedule, got \(String(describing: schedule))")
        }
    }

    @Test("Repeating alarm: weekends [0,6] maps to Sun, Sat")
    func repeatingWeekends() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 9, minute: 0, repeatDays: [0, 6])

        let schedule = scheduler.buildSchedule(from: config)

        if case .relative(let relative) = schedule {
            if case .weekly(let days) = relative.repeats {
                #expect(days.count == 2)
                #expect(days.contains(.sunday))
                #expect(days.contains(.saturday))
            } else {
                Issue.record("Expected .weekly repeats")
            }
        } else {
            Issue.record("Expected .relative schedule")
        }
    }

    @Test("Repeating alarm: all 7 days")
    func repeatingEveryDay() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 6, minute: 0, repeatDays: [0, 1, 2, 3, 4, 5, 6])

        let schedule = scheduler.buildSchedule(from: config)

        if case .relative(let relative) = schedule {
            if case .weekly(let days) = relative.repeats {
                #expect(days.count == 7)
            } else {
                Issue.record("Expected .weekly repeats")
            }
        } else {
            Issue.record("Expected .relative schedule")
        }
    }

    @Test("Repeating alarm: single day (Wednesday)")
    func repeatingSingleDay() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, repeatDays: [3])

        let schedule = scheduler.buildSchedule(from: config)

        if case .relative(let relative) = schedule {
            if case .weekly(let days) = relative.repeats {
                #expect(days.count == 1)
                #expect(days.contains(.wednesday))
            } else {
                Issue.record("Expected .weekly repeats")
            }
        } else {
            Issue.record("Expected .relative schedule")
        }
    }

    @Test("Repeating alarm: invalid indices filtered out")
    func repeatingInvalidIndicesFiltered() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, repeatDays: [1, 7, 3, -1, 100])

        let schedule = scheduler.buildSchedule(from: config)

        if case .relative(let relative) = schedule {
            if case .weekly(let days) = relative.repeats {
                #expect(days.count == 2) // Only Monday (1) and Wednesday (3) survive
                #expect(days.contains(.monday))
                #expect(days.contains(.wednesday))
            } else {
                Issue.record("Expected .weekly repeats")
            }
        } else {
            Issue.record("Expected .relative schedule")
        }
    }

    @Test("Repeating alarm: all invalid indices returns nil")
    func repeatingAllInvalidReturnsNil() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, repeatDays: [7, -1, 100])

        let schedule = scheduler.buildSchedule(from: config)
        #expect(schedule == nil)
    }

    // MARK: - Day Index Mapping

    @Test("Day index 0 maps to Sunday")
    func dayIndex0() {
        let scheduler = makeScheduler()
        #expect(scheduler.mapDayIndexToWeekday(0) == .sunday)
    }

    @Test("Day index 1 maps to Monday")
    func dayIndex1() {
        let scheduler = makeScheduler()
        #expect(scheduler.mapDayIndexToWeekday(1) == .monday)
    }

    @Test("Day index 2 maps to Tuesday")
    func dayIndex2() {
        let scheduler = makeScheduler()
        #expect(scheduler.mapDayIndexToWeekday(2) == .tuesday)
    }

    @Test("Day index 3 maps to Wednesday")
    func dayIndex3() {
        let scheduler = makeScheduler()
        #expect(scheduler.mapDayIndexToWeekday(3) == .wednesday)
    }

    @Test("Day index 4 maps to Thursday")
    func dayIndex4() {
        let scheduler = makeScheduler()
        #expect(scheduler.mapDayIndexToWeekday(4) == .thursday)
    }

    @Test("Day index 5 maps to Friday")
    func dayIndex5() {
        let scheduler = makeScheduler()
        #expect(scheduler.mapDayIndexToWeekday(5) == .friday)
    }

    @Test("Day index 6 maps to Saturday")
    func dayIndex6() {
        let scheduler = makeScheduler()
        #expect(scheduler.mapDayIndexToWeekday(6) == .saturday)
    }

    @Test("Negative day index returns nil")
    func dayIndexNegative() {
        let scheduler = makeScheduler()
        #expect(scheduler.mapDayIndexToWeekday(-1) == nil)
    }

    @Test("Day index 7 returns nil")
    func dayIndex7() {
        let scheduler = makeScheduler()
        #expect(scheduler.mapDayIndexToWeekday(7) == nil)
    }

    @Test("Day index 100 returns nil")
    func dayIndex100() {
        let scheduler = makeScheduler()
        #expect(scheduler.mapDayIndexToWeekday(100) == nil)
    }

    // MARK: - Snooze Duration

    @Test("Snooze 1 minute = 60 seconds")
    func snooze1Min() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, snoozeInterval: 1)
        let duration = scheduler.buildCountdownDuration(from: config)
        #expect(duration.postAlert == 60.0)
    }

    @Test("Snooze 5 minutes = 300 seconds")
    func snooze5Min() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, snoozeInterval: 5)
        let duration = scheduler.buildCountdownDuration(from: config)
        #expect(duration.postAlert == 300.0)
    }

    @Test("Snooze 15 minutes = 900 seconds")
    func snooze15Min() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, snoozeInterval: 15)
        let duration = scheduler.buildCountdownDuration(from: config)
        #expect(duration.postAlert == 900.0)
    }

    @Test("Snooze 10 minutes = 600 seconds")
    func snooze10Min() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, snoozeInterval: 10)
        let duration = scheduler.buildCountdownDuration(from: config)
        #expect(duration.postAlert == 600.0)
    }

    // MARK: - Alarm Title

    @Test("Calm tone title")
    func titleCalm() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, tone: .calm)
        let title = scheduler.buildAlarmTitle(from: config)
        #expect(String(localized: title) == "Calm Wake Up")
    }

    @Test("Encourage tone title")
    func titleEncourage() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, tone: .encourage)
        let title = scheduler.buildAlarmTitle(from: config)
        #expect(String(localized: title) == "Encouraging Wake Up")
    }

    @Test("Push tone title")
    func titlePush() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, tone: .push)
        let title = scheduler.buildAlarmTitle(from: config)
        #expect(String(localized: title) == "Motivating Wake Up")
    }

    @Test("Strict tone title")
    func titleStrict() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, tone: .strict)
        let title = scheduler.buildAlarmTitle(from: config)
        #expect(String(localized: title) == "Strict Wake Up")
    }

    @Test("Fun tone title")
    func titleFun() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, tone: .fun)
        let title = scheduler.buildAlarmTitle(from: config)
        #expect(String(localized: title) == "Fun Wake Up")
    }

    @Test("Other tone title")
    func titleOther() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, tone: .other)
        let title = scheduler.buildAlarmTitle(from: config)
        #expect(String(localized: title) == "Custom Wake Up")
    }

    @Test("Nil tone title")
    func titleNil() {
        let scheduler = makeScheduler()
        let config = makeConfig(hour: 7, minute: 0, tone: nil)
        let title = scheduler.buildAlarmTitle(from: config)
        #expect(String(localized: title) == "Wake Up")
    }
}
