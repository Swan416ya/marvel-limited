// ML Kit 的库模块（google_mlkit_commons-0.6.1）把 compileSdkVersion 写死成 29，
// 编译时缺 android:attr/lStar。必须在**评估前**注册 afterEvaluate 才能覆盖它
// （放在 evaluationDependsOn 之后注册会报 "project is already evaluated"）。
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                ?.let { ext ->
                    if ((ext.compileSdk ?: 0) < 36) {
                        ext.compileSdk = 36
                    }
                }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
