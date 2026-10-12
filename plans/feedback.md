# Feeback Button and Crash Report

I want to add a "feedback" button in my app and a crash-report functionality.

## About the feedback server

This server is already implemented. This section is just for information.

The feedback server is a http server that receives the feedback and crash report data. 
It has two API: health (to check if it is reachable) and submit (to send the data).

The server is running at:
```
https://www.localhost/api/v1/feedback-x92z/
```
so that the health request would be `https://www.localhost/api/v1/feedback-x92z/health`.

Feedback/crash report data is sent as a multipart/form-data HTTP request, include the app-id (`X-App-ID: pianoscope`). It is sent as a POST request. The body is `multipart/form-data` with these parts:

| Part                  | Type | Required | Notes                                                                          |
|-----------------------|------|----------|--------------------------------------------------------------------------------|
| `message`             | text | **yes**  | Must be non-empty after trimming.                                              |
| `application_id`      | text | no       | Empty string if omitted.                                                       |
| `application_version` | text | no       | Empty string if omitted.                                                       |
| `platform`            | text | no       | Empty string if omitted.                                                       |
| `report`              | text | no       | Log excerpt or crash report. Up to 1 MB. Whitespace-only is treated as absent. |
| `screenshot`          | file | no       | Up to 10 MB.                                                                   |

- Example with curl:

```sh
curl -X POST http://127.0.0.1:3000/api/v1/feedback/submit \
  -F application_id=com.example.app \
  -F application_version=1.4.2 \
  -F platform=Android \
  -F message='the checkout button does nothing' \
  --form-string 'report=FATAL EXCEPTION: main
java.lang.NullPointerException
	at com.example.Save.save(Save.kt:42)' \
  -F screenshot=@/path/to/shot.png
```

## Crash Report 

The dart frontend and the rust backend must be capable of storing crash report in the application cache directory.

- Task 1: Determine the cache directory and pass it to the rust backend at initilization.
- Task 2: Rust panic interception. Setup a panic hook that write the stack trace and panic information.
- Task 3: Dart panic interception. Setup `PlatformDispatcher.instance.onError` that write the stack trace and panic information.

Rust and dart crash report should have the same format: json. Example:
```
{
    "dateime": "2026-10-11T05:40:12Z",
	"location": "foo.dart:123",
	"error_message": "blahblahblah",
	"stacktrace": "(the stacktrace)",
}
```
The files are named with an increasing counter: report-0001.json, report-0002.json, etc.

## Frontend Feedback dialog

We will make a reusable dialog for both feedback and crash reports. 

### Feedback mode 

The dialog has three input field:
  * user email (remembered as user settings, not mandatory)
  * a free text message 
  * a checkbox to send a screenshot of the current screen.

On the button, there are two button: Cancel and Submit.
This dialog is shown when the "feedback" hero button is pressed. The hero button is floating, always visible.

### Crash report mode 

In crash report mode, the user input fields are hidden. Instead, there is a text field saying that one or more crash report could be sent to improve the application.

Task 4: create the hero button and the dialog. Do not call any callback, this task is a pure UI task.

## Dart Callbacks and wiring with the dialog 

Before we send data to the monitoring server, i want to handle the case where the monitoring server in not reachable. For the crash reports, there is nothing to do since the data are already on disc/persistent storage. We need to extend that to user feedback. Since the data are shared between frontend and backend, we need a shared definition in rust. 
```
Feedback {
	email: String,
    message: String,
    screenshot: Vec[u8],	
}
```
Sharing the definition of crash reports will make things easier to read.

Task 5: create the Feedback struct in `backend/src/report.rs` and expose it to the frontend side, probably in a separate frontend module ("report.rs"). Expose the `CrashReport` struct too and replace the parameters of `write_report` (location, error_message, ..) with that CrashReport struct. 

The frontend will show a progress dialog when data still in the `reports` cache (i.e. not sent yet) is sent to the server. The uploads will be triggered one-by-one by the frontend. I needs to get a list of filenames to send.

Task 6: Retrieve the (feedback and crash reports) filename list:
rust function in backend/src/report.rs
```
pub fn reports_list() -> Vec<String> 
```
exposed to the frontend (in "frontend/rust/..../report.rs").

Then, the frontend will trigger the data upload one by one, implemented in task 6 and task 7.

Task 7: upload function on the backend side, with frontend exposure:
```
pub fn upload(filename:&String) -> Result<String, String>
```
This is a first draft, the error is converted to a string with "{:?}".

Then, the frontend will trigger the data upload one by one: Task 8.

Task 8: Right after initialization, check the count of reports to be sent. If count>0, open the feedback dialog in crash report mode. For each file, (1) display "uploading crash #n..." or "uploading feedback #n..." depending on the filename (if it contains "feedback", this is a feedback, otherwise this is a crash report) in the text field, and (2) trigger the upload function. In this first version, the user has no possibility to cancel the upload: submit and cancel buttons are disabled.

Now implementing the feedback upload for the submit button is easy.

Task 9: When the user clicks on submit, write the report in the cache (which return the filename). Then upload the filement using the `upload` (which autonomously deletes the file in the cache).
