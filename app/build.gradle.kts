import com.github.spotbugs.snom.Confidence
import com.github.spotbugs.snom.Effort

plugins {
    java
    id("org.springframework.boot") version "3.2.5"
    id("io.spring.dependency-management") version "1.1.5"
    id("checkstyle")
    id("pmd")
    id("com.github.spotbugs") version "6.0.18"
    id("jacoco")
}

group = "com.example"
version = "0.0.1-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

configurations {
    create("integrationTestImplementation") {
        extendsFrom(configurations.testImplementation.get())
    }
    create("integrationTestRuntimeOnly") {
        extendsFrom(configurations.testRuntimeOnly.get())
    }
}

val integrationTestSourceSet = sourceSets.create("integrationTest") {
    java.srcDir("src/integrationTest/java")
    resources.srcDir("src/integrationTest/resources")
    compileClasspath += sourceSets.main.get().output + configurations["integrationTestImplementation"]
    runtimeClasspath += output + compileClasspath + configurations["integrationTestRuntimeOnly"]
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    testImplementation("org.springframework.boot:spring-boot-starter-test") {
        exclude(group = "org.junit.vintage", module = "junit-vintage-engine")
    }
    // REST Assured for integration tests
    add("integrationTestImplementation", "io.rest-assured:rest-assured:5.4.0")
    add("integrationTestImplementation", "io.rest-assured:json-path:5.4.0")
    add("integrationTestImplementation", "org.springframework.boot:spring-boot-starter-test") {
        exclude(group = "org.junit.vintage", module = "junit-vintage-engine")
    }
    add("integrationTestRuntimeOnly", "org.junit.platform:junit-platform-launcher")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    // SpotBugs annotations
    compileOnly("com.github.spotbugs:spotbugs-annotations:4.8.4")
}

// ─── Checkstyle ────────────────────────────────────────────────────────────────
checkstyle {
    toolVersion = "10.14.2"
    configFile = file("config/checkstyle/checkstyle.xml")
    isIgnoreFailures = true   // warn only per brief
    maxWarnings = 200
}

tasks.withType<Checkstyle> {
    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

// ─── PMD ────────────────────────────────────────────────────────────────────────
pmd {
    toolVersion = "7.2.0"
    ruleSetFiles = files("config/pmd/ruleset.xml")
    isIgnoreFailures = true
}

tasks.withType<Pmd> {
    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

// ─── SpotBugs ───────────────────────────────────────────────────────────────────
spotbugs {
    toolVersion = "4.8.4"
    effort = Effort.DEFAULT
    reportLevel = Confidence.MEDIUM
    ignoreFailures = true
}

tasks.withType<com.github.spotbugs.snom.SpotBugsTask> {
    reports.create("html") {
        required.set(true)
        outputLocation.set(layout.buildDirectory.file("reports/spotbugs/${name}.html"))
    }
    reports.create("xml") {
        required.set(true)
        outputLocation.set(layout.buildDirectory.file("reports/spotbugs/${name}.xml"))
    }
}

// ─── JaCoCo ─────────────────────────────────────────────────────────────────────
jacoco {
    toolVersion = "0.8.11"
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

tasks.jacocoTestCoverageVerification {
    dependsOn(tasks.jacocoTestReport)
    violationRules {
        rule {
            limit {
                minimum = "0.70".toBigDecimal()
            }
        }
    }
}

// ─── Tests ──────────────────────────────────────────────────────────────────────
tasks.test {
    useJUnitPlatform()
    finalizedBy(tasks.jacocoTestReport)
}

val integrationTest = task<Test>("integrationTest") {
    description = "Runs integration tests."
    group = "verification"
    useJUnitPlatform()
    testClassesDirs = integrationTestSourceSet.output.classesDirs
    classpath = integrationTestSourceSet.runtimeClasspath
    shouldRunAfter(tasks.test)
}

tasks.check { dependsOn(integrationTest) }
