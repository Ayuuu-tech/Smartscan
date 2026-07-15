buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

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

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. cunning_document_scanner) still declare an old
// compileSdk; their androidx dependencies need at least 34. Force a
// modern compileSdk on every Android subproject.
fun Project.bumpCompileSdk() {
    extensions.findByName("android")?.let { ext ->
        val androidExt = ext as com.android.build.gradle.BaseExtension
        if ((androidExt.compileSdkVersion ?: "").removePrefix("android-")
                .toIntOrNull()?.let { it < 35 } == true
        ) {
            androidExt.compileSdkVersion(35)
        }
    }
}

subprojects {
    if (state.executed) {
        bumpCompileSdk()
    } else {
        afterEvaluate { bumpCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
