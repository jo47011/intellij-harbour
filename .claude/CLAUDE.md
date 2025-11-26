# IntelliJ Harbour Plugin - Claude Instructions

## Formatting Test Framework

### How to Test Formatter Changes

Run the formatting test to validate PostFormatProcessor changes:

```bash
./gradlew test --tests "HarbourFormattingTest.testFormatAndCompileAllFiles"
```

### How It Works

1. `HarbourFormattingTest.java` calls `formatHarbourCodeWithDefaults()` on PRG files
2. Formats the file using our PostFormatProcessor logic
3. Compiles with Harbour compiler to verify no syntax errors
4. Restores backup if compilation fails

### Key Files

- `HarbourPostFormatProcessor.java` - Main formatter, has `formatHarbourCodeWithDefaults()` public method
- `HarbourFormattingTest.java` - Test class in `src/test/java/`
- Test files: `dummyjob.prg`, `errorsys.prg`, `hilfdef.prg` in `hbmiki-test-windows/`

### Adding More Test Files

Edit `COMPILABLE_FILES` array in `HarbourFormattingTest.java`:
```java
private static final String[] COMPILABLE_FILES = {
    "dummyjob.prg", "errorsys.prg", "hilfdef.prg"
};
```

### Important Notes

- Do NOT use `format.sh` - it doesn't call PostFormatProcessor
- Always run formatting test after modifying PostFormatProcessor
- Test creates `.bak` backup files, restores on failure
