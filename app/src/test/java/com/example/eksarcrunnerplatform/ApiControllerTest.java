package com.example.eksarcrunnerplatform;

import com.example.eksarcrunnerplatform.controller.AppController;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Checklist-compatible test alias for AppController.
 * The authoritative tests live in controller/AppControllerTest.java;
 * this class re-runs the same scenarios under the expected package path.
 */
@WebMvcTest(AppController.class)
class ApiControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("GET / returns EKS ARC Runner Platform message")
    void rootEndpointReturnsMessage() throws Exception {
        mockMvc.perform(get("/").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.message").value("EKS ARC Runner Platform"));
    }

    @Test
    @DisplayName("GET /health returns UP status")
    void healthEndpointReturnsUp() throws Exception {
        mockMvc.perform(get("/health").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.service").value("spring-boot-app"));
    }

    @Test
    @DisplayName("GET /hello returns Hello from EKS message")
    void helloEndpointReturnsGreeting() throws Exception {
        mockMvc.perform(get("/hello").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Hello from EKS!"));
    }
}
