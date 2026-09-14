package com.example.eksarcrunnerplatform.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Primary REST controller exposing platform endpoints.
 */
@RestController
public class AppController {

    /**
     * Root endpoint — platform identity.
     *
     * @return 200 with platform name
     */
    @GetMapping("/")
    public ResponseEntity<Map<String, String>> root() {
        return ResponseEntity.ok(Map.of("message", "EKS ARC Runner Platform"));
    }

    /**
     * Health endpoint — shallow liveness check.
     *
     * @return 200 with status payload
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
                "status", "UP",
                "service", "spring-boot-app"
        ));
    }

    /**
     * Hello endpoint — demonstration resource.
     *
     * @return 200 with greeting
     */
    @GetMapping("/hello")
    public ResponseEntity<Map<String, String>> hello() {
        return ResponseEntity.ok(Map.of("message", "Hello from EKS!"));
    }
}
