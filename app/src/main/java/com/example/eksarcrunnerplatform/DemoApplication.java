package com.example.eksarcrunnerplatform;

/**
 * Alias entry point — delegates to EksArcRunnerPlatformApplication.
 * Kept for checklist compatibility; the canonical main class is
 * {@link EksArcRunnerPlatformApplication}.
 */
public final class DemoApplication {

    private DemoApplication() {
        // utility class
    }

    /**
     * Delegating main method.
     *
     * @param args command-line arguments
     */
    public static void main(final String[] args) {
        EksArcRunnerPlatformApplication.main(args);
    }
}
