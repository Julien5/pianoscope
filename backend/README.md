## test results 

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 1 filtered out; finished in 0.00s


running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s


running 1 test
57 good, 27 bad
bad: /home/julien/delme/old-piano-recordings/position-1/C1/mark-4-C.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C2/mark-20-E.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C2/mark-21-F.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C2/mark-26-A#.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C3/mark-28-C.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C3/mark-32-E.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C3/mark-33-F.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C3/mark-36-G#.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C5/mark-61-A.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C6/mark-64-C.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C6/mark-71-G.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C6/mark-72-G#.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C6/mark-73-A.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C6/mark-74-A#.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C6/mark-75-B.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-76-C.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-77-C#.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-78-D.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-79-D#.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-80-E.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-81-F.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-82-F#.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-83-G.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-84-G#.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-85-A.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-86-A#.wav
bad: /home/julien/delme/old-piano-recordings/position-1/C7/mark-87-B.wav
test old_piano_samples ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 42.16s


running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

```
[julien@Z231] backend $ cat /tmp/old-piano-bad.txt | grep position-2 | wc -l
22
[julien@Z231] backend $ cat /tmp/old-piano-bad.txt | grep position-1 | wc -l
26
```
