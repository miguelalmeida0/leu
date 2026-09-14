# Shelf V20 Haptic Matrix

| Interaction | Semantic event | Implementation | Character | Fallback / guard | Physical verification |
|---|---|---|---|---|---|
| Topic/time choice | `selectionChanged` | `UISelectionFeedbackGenerator` | very light tick | no-op when haptics disabled | Pending real iPhone V20 QA |
| Standard control commit | `controlPressed` | light impact | short/crisp | optional | Pending |
| Learning object capture | `objectCaptured` | medium impact | soft settle | optional | Pending |
| Connection created | `objectConnected` | medium impact | rounded settle | optional | Pending |
| Reconstruction snap | `snapToTarget` | medium impact | one snap, no continuous vibration | optional | Pending |
| Answer commit | `answerCommitted` | light impact | crisp commitment | optional | Pending |
| Correct answer | `answerCorrect` | system success | restrained positive confirmation | optional | Pending |
| Incorrect answer | `answerIncorrect` | soft impact | muted, non-punitive | optional | Pending |
| Source revealed | `sourceRevealed` | light impact | subtle release | optional | Pending |
| Memory state strengthened | `memoryStrengthened` | system success | rare positive cue | optional | Pending |
| Study session starts | `studySessionStarted` | soft impact | quiet start | optional | Pending |
| Study session completes | `studySessionCompleted` | Core Haptics two transients, 90 ms apart | Shelf signature | system success if Core Haptics unavailable | Pending |
| Recording starts | `recordingStarted` | rigid impact before recorder starts | crisp | establishes recording guard after haptic | Pending microphone contamination check |
| Recording stops | `recordingStopped` | soft impact after recorder stops | closing settle | clears recording guard | Pending |
| Destructive warning | `destructiveWarning` | system warning | standard warning | optional | Pending |
| Legacy page/chapter/mark | semantic legacy events | light/medium impact | restrained | preserves V19 behavior | Prior V19 device QA; V20 regression pending |

Rules enforced in code: haptics can be disabled; intensity is user-controlled; normal scrolling has no continuous haptics; haptic failure does not block UI; non-stop tactile events are suppressed while an explanation is recording.
