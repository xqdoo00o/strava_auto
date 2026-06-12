buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.20")
    }
}

import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

subprojects {
    // 1. 处理 Kotlin 编译任务
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            // 使用更通用的方式设置 JVM 目标
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
        }
    }

    // 2. 处理 Java 编译任务
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_21.toString()
        targetCompatibility = JavaVersion.VERSION_21.toString()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
