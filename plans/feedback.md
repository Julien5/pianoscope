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

- Task 4: Send the crash report. When the flutter application starts up, it checks if json report files exists. If so, it asks the user for approval to send them. It sends one submit request per file. 

## Frontend Feedback dialog

- Feedback button as a hero button (floating, always visible).
- When the user presses the feedback button, a ping/health http request is sent to the server to check it is reachable. 

- If the server is not available, a message is shown that the feedback will be stored locally and sent automatically when the ser
ver gets reachable. Then, the feedback is stored in a local json file stored in the application *cache*. 

- The feedback dialog has three field:
  * user email (remembered as user settings, not mandatory)
  * a free text message 
  * a checkbox to send a screenshot of the current screen.
  
- When the user clicks on the submit button, the `submit` http request is sent. 

Task: create the hero button and the dialog and implement the submit callback that sends the submit request. 
