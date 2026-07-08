allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// ─────────────────────────────────────────────────────────────
// compileSdk override for every library subproject.
//
// Some plugins ship with compileSdk = 34 but their transitive
// deps require 36; Gradle's CheckAarMetadata then aborts. The
// override MUST be registered BEFORE the evaluationDependsOn(":app")
// block below — otherwise the target projects are already
// evaluated and Gradle refuses to attach the afterEvaluate.
// See .cursor/rules/gray_part_pitfalls.md §2 and §7.
// ─────────────────────────────────────────────────────────────
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
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
