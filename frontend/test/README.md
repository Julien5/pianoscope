# flutter test 

## Run the tests

```
flutter test
```

## Update goldens 

```
flutter test --update-goldens
```

## Strip output

```
[julien@Z231] frontend $ 2>&1 flutter test | grep -A2 assertion
The following assertion was thrown while running async test code:
Golden "goldens/grand_staff_idle.png": Pixel test failed, image sizes do not match.
Master Image: 800 X 262
--
The following assertion was thrown while running async test code:
Golden "goldens/grand_staff_bass40.png": Pixel test failed, image sizes do not match.
Master Image: 800 X 262
--
The following assertion was thrown while running async test code:
Golden "goldens/grand_staff_bass55.png": Pixel test failed, image sizes do not match.
Master Image: 800 X 262
--
The following assertion was thrown while running async test code:
Golden "goldens/grand_staff_treble60.png": Pixel test failed, image sizes do not match.
Master Image: 800 X 262
--
The following assertion was thrown while running async test code:
Golden "goldens/grand_staff_treble72.png": Pixel test failed, image sizes do not match.
Master Image: 800 X 262
```
