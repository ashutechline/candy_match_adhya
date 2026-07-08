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
    try {
        project.projectDir.toPath().relativize(newSubprojectBuildDir.asFile.toPath())
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    } catch (e: IllegalArgumentException) {
        // Different roots (e.g. on different Windows drives). Keep the default build directory to avoid Gradle errors.
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
