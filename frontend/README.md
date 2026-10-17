
## bake icons into the app 

```
./make-icon.sh -c assets/icon.png
mkdir -p assets/icon && cp /tmp/android-icons/flutter/*.png assets/icon/
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

./make-icon.sh assets/icon.png; mkdir -p assets/icon && cp /tmp/android-icons/flutter/*.png assets/icon/; dart run flutter_launcher_icons; ./run.sh --target android-arm64


