package com.example.eksarcrunnerplatform.integration;

import io.restassured.RestAssured;
import io.restassured.response.Response;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;

/**
 * REST Assured integration tests — executed against a live running instance.
 * Set APP_URL environment variable (e.g. http://localhost:8080) before running.
 */
class IntegrationTest {

    @BeforeEach
    void setUp() {
        String appUrl = System.getenv().getOrDefault("APP_URL", "http://localhost:8080");
        RestAssured.baseURI = appUrl;
    }

    @Test
    @DisplayName("GET / returns EKS ARC Runner Platform message")
    void rootEndpointReturnsMessage() {
        given()
            .accept("application/json")
        .when()
            .get("/")
        .then()
            .statusCode(200)
            .body("message", equalTo("EKS ARC Runner Platform"));
    }

    @Test
    @DisplayName("GET /health returns UP")
    void healthEndpointReturnsUp() {
        given()
            .accept("application/json")
        .when()
            .get("/health")
        .then()
            .statusCode(200)
            .body("status", equalTo("UP"))
            .body("service", equalTo("spring-boot-app"));
    }

    @Test
    @DisplayName("GET /hello returns EKS greeting")
    void helloEndpointReturnsGreeting() {
        given()
            .accept("application/json")
        .when()
            .get("/hello")
        .then()
            .statusCode(200)
            .body("message", equalTo("Hello from EKS!"));
    }
}
