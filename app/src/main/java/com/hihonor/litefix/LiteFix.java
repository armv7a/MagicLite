package com.hihonor.litefix;

import android.util.Log;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.concurrent.atomic.AtomicBoolean;
import io.github.libxposed.api.XposedModule;

public final class LiteFix extends XposedModule {
    private static final String PACKAGE = "com.hihonor.android.launcher";
    private static final String TAG = "MagicLite";
    private boolean launcherProcess;
    private boolean installed;

    @Override
    public void onModuleLoaded(ModuleLoadedParam param) {
        launcherProcess = !param.isSystemServer() && PACKAGE.equals(param.getProcessName());
        if (launcherProcess) log(Log.INFO, TAG, "loaded " + param.getProcessName() + " API " + getApiVersion());
    }

    @Override
    public void onPackageReady(PackageReadyParam param) {
        if (!launcherProcess || installed || !PACKAGE.equals(param.getPackageName())) return;
        installed = true;
        ClassLoader loader = param.getClassLoader();
        String settings = PACKAGE + ".Settings";
        install(loader, settings, "isLiteDevice", false);
        install(loader, settings, "isLiteOrLowRecentAnim", false);
        install(loader, settings, "isEnhancedLiteDevice", false);
        // AnimScene can overwrite the cached card flag after Settings hooks are installed.
        install(loader, PACKAGE + ".quickstep.LowPerfAnimationHelper", "isCardAnimEnabled", true);
    }

    private void install(ClassLoader loader, String name, String methodName, boolean value) {
        try {
            Class<?> type = Class.forName(name, false, loader);
            Method method = type.getDeclaredMethod(methodName);
            if (!Modifier.isStatic(method.getModifiers()) || method.getReturnType() != boolean.class) {
                throw new NoSuchMethodException("Expected static boolean " + name + "." + methodName + "()");
            }
            AtomicBoolean observed = new AtomicBoolean();
            hook(method).setExceptionMode(ExceptionMode.PROTECTIVE).intercept(chain -> {
                if (observed.compareAndSet(false, true)) {
                    log(Log.INFO, TAG, "intercepted " + methodName + " -> " + value);
                }
                return Boolean.valueOf(value);
            });
            log(Log.INFO, TAG, "hooked " + methodName + " -> " + value);
        } catch (ClassNotFoundException e) {
            log(Log.ERROR, TAG, name.endsWith(".Settings") ? "Settings unavailable: " + methodName : "Class unavailable: " + name, e);
        } catch (Throwable e) {
            // Isolate each third-party hook failure so an unsupported launcher still starts.
            log(Log.ERROR, TAG, "failed " + methodName, e);
        }
    }
}
