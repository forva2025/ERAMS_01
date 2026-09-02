allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// agora_rtc_engine's android/build.gradle reads rootProject.ext.compileSdkVersion
// (via safeExtGet), falling back to a hardcoded 31 if unset — too low for its own
// transitive androidx deps (need 33+). Setting it here on rootProject.extra is
// visible to that Groovy safeExtGet() lookup since both share the same
// ExtraPropertiesExtension instance.
rootProject.extra["compileSdkVersion"] = 36

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                compileSdk = 36
                // flutter_local_notifications 8.2.0 (and other old, unmaintained
                // plugins) predate AGP 8's required `namespace` field and only
                // declare a `package` attribute in their AndroidManifest.xml,
                // which AGP 8 no longer falls back to — causing "Namespace not
                // specified" configuration failures. Backfill it from the
                // manifest's package attribute for any plugin that hasn't set
                // one, so upgrading AGP doesn't require patching every such
                // plugin individually.
                if (namespace == null) {
                    val manifest = file("src/main/AndroidManifest.xml")
                    if (manifest.exists()) {
                        val pkg = Regex("package=\"([^\"]+)\"")
                            .find(manifest.readText())?.groupValues?.get(1)
                        if (pkg != null) namespace = pkg
                    }
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
