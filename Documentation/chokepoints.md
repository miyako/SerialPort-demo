# Chokepoints, failures and findings

Everything below was hit while building this demo against
`miyako/SerialPort 0.1.2` on macOS arm64 with 4D 21 R5 (build 100175) and
tool4d 21R4 (build 100224). Each entry says what broke, why, and what to do
instead — the rule, not the anecdote.

## 1. Process and lifetime

### A worker callback needs a live worker, and the form cannot be that worker
`cs.Serial.SerialPort.new(target; callback)` delivers through
`4D.SystemWorker`, whose callbacks need a process with an event loop. A method
running in the form's process cannot receive them. The session therefore lives
in a `CALL WORKER` process; the form only displays it.

### `CALL FORM` from the owner worker into the window is unreliable
The first design had the worker push: `CALL FORM($window; Formula(...))`. In an
unattended application the formula bodies were frequently not executed, whether
the window was busy or idle, and there is no error to see. Replaced by
publish-and-poll:

* owner rewrites `Logs/session-status.json` — snapshot fields plus a numbered
  `outbox`;
* the window's form timer reads and parses that file and applies only messages
  with `seq` greater than its cursor.

This is idempotent, survives a stretched timer, and never crosses a process
boundary with an object.

### A process-scoped `var` starts as **Null**, not as 0
`var SERIAL_AppliedSeq : Integer` inside a method is *per process* and persists
between calls. In the window's process the first read is **Null**, and every
comparison with Null is false — the drain loop silently applied nothing for
several runs while the cursor looked "reasonable" in a dump. Seed it:
`If (Not(SerialDemoIsNumber(SERIAL_AppliedSeq))) SERIAL_AppliedSeq:=0 End if`.

## 2. 4D type semantics that fail silently

### `Is number` is not a `Value type` constant
`Value type($x)#Is number` compiles, runs, and is **always true**, because the
undefined constant evaluates to 0 and no type equals 0. Guards written this way
turn into unconditional `continue`/`return`. The real constants are
`Is real`, `Is integer`, `Is longint`; JSON numbers arrive as `Is real` (1).
`SerialDemoIsNumber` wraps the three, and every guard in this project uses it.

### `Value type` returns an Integer, not a name
`String(Value type($x))` is required before concatenation; `"type="+Value type($x)`
raises a type error at runtime, which in a form timer looks like "nothing
happened".

### Assigning an object aliases it
`$copy:=$source` in 4D does not copy an object; `$copy:=OB Copy($source; *)`
before `OB REMOVE`, or both references change. This bit the message model while
removing an applied message from the outbox.

### `JSON Parse` produces 0-based collections
`For ($index; 1; $collection.length)` throws. Use
`For ($index; 0; $collection.length-1)`, and check
`Value type($message)#Is object` before reading fields: a message can be a
scalar.

### `Error description` does not exist
An error handler that reads `Error description` fails to compile and takes the
whole run with it (no report, no log). Use `Error formula`, `Error method`,
`Error line`, `Error code`.

## 3. Paths — three different conventions in one call chain

| Value | Convention | Construct with |
| --- | --- | --- |
| `Get 4D folder(Database folder)` | HFS, **volume-qualified** (`Macintosh HD:Users:…:`) | `Folder(…; fk platform path)`, colon-join children |
| `.platformPath` of a 4D object | HFS on macOS | `File(x; fk platform path)` |
| path produced by Python / POSIX APIs | POSIX (`/Users/…`) | `File(x; fk posix path)` |

Two traps found here:

* `Folder(<HFS path>; fk platform path).posixPath` returns **empty**; convert
  explicitly with `Convert path system to POSIX(...)`.
* Passing `.platformPath` (HFS) into `File(x; fk posix path)` raises
  `A valid posix path was expected`. That is exactly what silently broke the
  headless suite: the entry method handed the worker an HFS path while the
  worker opens it as POSIX. Hand a worker the convention it names.

`4D.SystemWorker.new` needs a POSIX command line on macOS, so the simulator
script path is built with `File(...; fk posix path).platformPath` → converted,
never string-concatenated from an HFS folder.

## 4. Timers, ticks and an unattended app

* In an unattended (background) application macOS stretches form timers: a
  `SET TIMER(1000)` window was observed updating roughly every 16 s. Nothing in
  this project assumes a timer frequency; the poll is idempotent and the tests
  wait on **state**, never on a tick count.
* `DELAY PROCESS(process; n)` also stretches, so a test driver built from tick
  schedules can spend minutes "waiting" for something that already happened.
  `SerialDemoUIWait` re-reads the status document every round and stops as soon
  as the condition holds; a stalled wait costs the timeout, not the whole run.
* `DELAY PROCESS` does not deliver SystemWorker callbacks mid-loop. Any wait
  that must keep the session alive has to pump (`CALL FORM(...; SerialDemoPump)`)
  or read published state.
* A GUI 4D application publishes nothing to stdout. `LOG EVENT(Into system
  standard outputs; …)` works in tool4d only; an application can only be
  observed through files it writes itself. Plan the harness around that.

## 5. The component's own limits and reply shapes

Verified against 0.1.2:

* a **frame** is at most 65536 bytes; a **decoded write** is at most 32768
  bytes; a read chunk is at most 4096 bytes;
* at most 16 connections and 128 pending requests per session;
* three distinct replies: a **queued** acknowledgement (`request queued as N`),
  a **request** reply keyed by id, and unsolicited **event** messages (`data`,
  `disconnected`, `terminated`);
* `open` returns a connection id; every later call names it, and an unknown id
  is rejected rather than ignored;
* `baudRate: 0` is rejected **asynchronously** — the call is accepted, the error
  arrives later as an event. A test that asserts on the return value sees
  success;
* `cancel(<unknown id>)` is rejected, so cancellation needs the real request id;
* `shutdown` drains and ends with phase `terminated`; `terminate` kills.

## 6. PTY behaviour (the simulator side)

* `select()` on a PTY **master** does not report writability usefully; the
  simulator detects a blocked reader from the write itself and stops streaming
  instead of spinning.
* A PTY has roughly 1 KB of buffer before writes block. `MULTI` is truncated at
  1022 bytes — which is a feature here: it shows what a real device does when
  nobody drains.
* `/dev/ptmx` is blocked under the older 4D sandbox; opening the master has to
  happen in the helper process, never in 4D.
* **A line-oriented device splits on LF.** Sending `Char(13)` alone (a terminal
  `CR`) leaves the device buffering forever and it looks silent. This cost the
  longest debugging session of the project: writes were accepted (`sent` grew),
  no error came back, and `received` stayed 0. `SerialDemoSend` now normalises
  the terminator to CRLF.

## 7. Harness-only lessons

* A report written as `{success:true, cases:[]}` **before** the run finishes is
  easy to mistake for a result. Wait for `finished:true`, not for a file to
  exist.
* Every wait needs a state-based exit; a tick budget will be spent in full.
* `FORM GET OBJECTS` requires `ARRAY POINTER`, and `GET OBJECT PROPERTY` on a
  listbox needs the object name, so dumping a form is worth a dedicated method
  (`SerialPortDemoUIDump`) rather than an inline loop.
* Leftover helper processes are the norm: `pkill -9 -f virtual_serial.py` after
  every run, or 30+ PTY helpers accumulate. Worse, the kernel reuses the freed
  `/dev/ttysNNN`, so the next run can attach a **new** simulator and a **stale**
  owner to the same device — the suite then reports "0 chunks were decoded"
  while every step claims success. `tools/processes.py` reaps helpers before
  each run; nothing else caught this reliably.
* A dependency in **download mode** is two things, not one: the unpacked folder
  under `.local-components/` *and* `environment4d.json` mapping the name to that
  folder. Unpacking alone leaves `Dependency '…' cannot be found`. Also, a
  naive `zipfile.extract` drops the ZIP's permission bits, so the bundled CLI
  stops being executable and every session fails with `POSIX 13` — restore the
  modes from the archive entries.

## 8. What is **not** verified here

* Windows x64 and Intel macOS execution of the component — no such 4D runtime
  was available; only arm64 macOS was run.
* Real serial hardware. Every result above came from the PTY simulator, which
  can model back-pressure and silence but not electrical or driver behaviour.
* Signing, notarization, and dependency-manager installation from a published
  release asset: the component was resolved from the released ZIP in download
  mode on one machine.
