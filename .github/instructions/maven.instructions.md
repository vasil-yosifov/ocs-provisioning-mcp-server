---
description: This file describes Maven POM conventions and required plugins/dependencies for the project.
applyTo: **/pom.xml
---
# Maven Instructions
You are an expert in Maven and Java build tooling. When creating or editing a `pom.xml`, follow these rules to keep builds lean, reproducible, and container-ready.

## Core principles
- Prefer the minimum required dependencies. Only add what is necessary for the code being introduced.
- Always include Lombok for Java projects and configure it so it is not packaged at runtime.
- Always configure the fabric8 Docker Maven Plugin to produce a Docker image as part of the build.
- Use a dedicated external `Dockerfile` for image builds (avoid inline base image/resources/entrypoint configuration in the plugin).
- Pin versions via `<properties>` and avoid scattering hard-coded versions.
- If using Spring Boot, prefer the official parent or BOM for dependency management; otherwise, manage versions explicitly.
- Keep plugin configuration minimal; enable only required goals and phases.

## Required properties (example)
Add properties for commonly used versions; keep them centralized and updated.

```xml
<properties>
  <!-- Java toolchain -->
  <maven.compiler.release>17</maven.compiler.release>

  <!-- Versions -->
  <lombok.version>REPLACE_WITH_STABLE</lombok.version>
  <docker.maven.plugin.version>REPLACE_WITH_STABLE</docker.maven.plugin.version>
</properties>
```

Notes:
- Use only `<maven.compiler.release>` OR `<maven.compiler.source/target>`; prefer `release`.
- If the parent POM already defines Java version, do not duplicate it here.

## Minimum dependencies
Always keep dependencies minimal. For Lombok, use `provided` scope and mark it `optional` to avoid bundling it in the runnable artifact.

```xml
<dependencies>
  <!-- Lombok: compile-time only -->
  <dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <version>${lombok.version}</version>
    <scope>provided</scope>
    <optional>true</optional>
  </dependency>

  <!-- Add only what the code requires (examples) -->
  <!-- For REST controllers: spring-boot-starter-web -->
  <!-- For data access with JPA: spring-boot-starter-data-jpa -->
  <!-- For testing: junit-jupiter + spring-boot-starter-test (if using Spring Boot) -->
</dependencies>
```

If the project uses Spring Boot:
- Prefer `spring-boot-starter-parent` as `<parent>` or import the Spring Boot BOM under `<dependencyManagement>`.
- Do not specify versions for Spring Boot starters when using the parent/BOM; let the BOM control them.

## Compiler plugin (minimal)
Only declare this if not inherited from a parent. Keep it minimal.

```xml
<build>
  <plugins>
    <plugin>
      <groupId>org.apache.maven.plugins</groupId>
      <artifactId>maven-compiler-plugin</artifactId>
      <configuration>
        <release>${maven.compiler.release}</release>
      </configuration>
    </plugin>
  </plugins>
</build>
```

Lombok works with default annotation processing; do not add extra configuration unless required by the environment.

## Docker image with fabric8 Docker Maven Plugin (required)
Always configure the fabric8 Docker Maven Plugin so a Docker image is built at `package` phase using a dedicated external `Dockerfile`.

```xml
<build>
  <plugins>
    <plugin>
      <groupId>io.fabric8</groupId>
      <artifactId>docker-maven-plugin</artifactId>
      <version>${docker.maven.plugin.version}</version>
      <configuration>
        <images>
          <image>
            <name>${project.groupId}/${project.artifactId}:${project.version}</name>
            <build>
              <!-- Use external Dockerfile -->
              <dockerFile>${project.basedir}/Dockerfile</dockerFile>
              <contextDir>${project.basedir}</contextDir>
              <!-- Pass the JAR file name as a build-arg for use in the Dockerfile -->
              <args>
                <JAR_FILE>target/${project.build.finalName}.jar</JAR_FILE>
              </args>
            </build>
          </image>
        </images>
      </configuration>
      <executions>
        <execution>
          <id>build-docker-image</id>
          <phase>package</phase>
          <goals>
            <goal>build</goal>
          </goals>
        </execution>
      </executions>
    </plugin>
  </plugins>
</build>
```

Notes:
- Place the `Dockerfile` at the module root (`${project.basedir}/Dockerfile`).
- The plugin uses `contextDir` to define the Docker build context (project root by default).
- Name the image using `${project.groupId}/${project.artifactId}:${project.version}` for consistency.
- The JAR file is passed as a build argument and must be available in the build context.

### Dockerfile (minimal example)
Create a `Dockerfile` next to the module `pom.xml` with the following minimal content:

```dockerfile
FROM eclipse-temurin:17-jre

# JAR file name is supplied by the Maven plugin as a build-arg
ARG JAR_FILE=target/app.jar

WORKDIR /app
COPY ${JAR_FILE} app.jar

EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
```

Note: The `JAR_FILE` argument includes the `target/` prefix as it's relative to the build context (project root).

## Troubleshooting
- Dockerfile not found: Ensure the file exists at `${project.basedir}/Dockerfile` and the plugin points to it via `<dockerFile>` and `<contextDir>${project.basedir}</contextDir>`.
- JAR not found in build context: Ensure `.dockerignore` allows `target/*.jar` files. The fabric8 plugin uses the entire `contextDir` as the Docker build context.
- Build arg not applied: Confirm your Dockerfile declares `ARG JAR_FILE` before `COPY` and that the plugin sets `<args><JAR_FILE>target/${project.build.finalName}.jar</JAR_FILE></args>`.
- Docker not running/permission denied: Start Docker Desktop (macOS/Windows) or ensure Docker daemon is running (Linux) and your user can run Docker commands.
- Multi-module pitfalls: Apply the Docker plugin only to modules that produce runnable artifacts; avoid adding it to parent/aggregator modules.
- ARM64 compatibility: The fabric8 plugin is fully compatible with ARM64 (Apple Silicon), Linux, and Windows platforms.

## Testing (minimal guidance)
- Use JUnit 5 (`junit-jupiter`) only; avoid legacy JUnit 4 unless strictly required.
- For Spring Boot projects, rely on `spring-boot-starter-test` and avoid duplicating transitive test libs unless needed.

## Multi-module projects
- Put common properties in the root POM.
- Apply the Docker plugin only to the modules that produce runnable artifacts (e.g., the service module), not to parent or pure library modules.

### Parent/child version alignment via properties (required)
- Define all shared dependency and plugin versions once in the parent POM under `<properties>`.
- In child POMs, do not hard-code versions. Either:
  - Omit versions entirely when they are managed by a parent BOM/`<dependencyManagement>`, or
  - Reference the parent property with `${...}` if a version must be specified.
- Use consistent property names across the build (e.g., `lombok.version`, `docker.maven.plugin.version`).
- Do not override parent-managed versions in children unless absolutely necessary; if overridden, leave a short comment explaining why.

Example parent POM properties:

```xml
<project>
  <!-- ... -->
  <properties>
    <maven.compiler.release>17</maven.compiler.release>

    <!-- Centralized versions -->
    <lombok.version>REPLACE_WITH_STABLE</lombok.version>
    <docker.maven.plugin.version>REPLACE_WITH_STABLE</docker.maven.plugin.version>
    <!-- Example: Spring Boot if not using parent/BOM -->
    <spring.boot.version>REPLACE_WITH_STABLE</spring.boot.version>
  </properties>

  <!-- Optional but recommended: manage dependency versions here -->
  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-dependencies</artifactId>
        <version>${spring.boot.version}</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>
  <!-- ... -->
</project>
```

Example child POM usage:

```xml
<project>
  <parent>
    <groupId>com.example</groupId>
    <artifactId>parent</artifactId>
    <version>1.0.0</version>
  </parent>

  <dependencies>
    <!-- Lombok aligned to parent property -->
    <dependency>
      <groupId>org.projectlombok</groupId>
      <artifactId>lombok</artifactId>
      <version>${lombok.version}</version>
      <scope>provided</scope>
      <optional>true</optional>
    </dependency>

    <!-- If Spring Boot BOM is imported by parent: omit version -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
      <!-- version omitted; managed by parent BOM -->
    </dependency>
    <!-- If not using BOM, explicitly reference parent property
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
      <version>${spring.boot.version}</version>
    </dependency>
    -->
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>io.fabric8</groupId>
        <artifactId>docker-maven-plugin</artifactId>
        <version>${docker.maven.plugin.version}</version>
      </plugin>
    </plugins>
  </build>
</project>
```

## Versioning and reproducibility
- Pin all direct dependency and plugin versions via `<properties>` or a BOM; avoid `LATEST` or `RELEASE`.
- Keep the property names consistent across modules (e.g., `lombok.version`, `docker.maven.plugin.version`).

## Acceptance criteria for edits
- POM builds successfully with only the necessary dependencies.
- Lombok is present with `provided` scope and does not bloat the runtime image.
- Docker image builds automatically at `mvn package` via the fabric8 plugin.
- Versions are centralized in `<properties>` or controlled by a BOM; no duplicated hard-coded versions.
