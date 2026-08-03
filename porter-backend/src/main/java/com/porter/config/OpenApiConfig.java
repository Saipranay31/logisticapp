package com.porter.config;

import io.swagger.v3.oas.models.ExternalDocumentation;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Swagger/OpenAPI configuration. Access at /swagger-ui.html
 */
@Configuration
public class OpenApiConfig {

  @Bean
  public OpenAPI porterOpenAPI() {
    return new OpenAPI()
        .info(new Info()
            .title("Porter Backend API")
            .version("1.0.0")
            .description("Ride-sharing & logistics platform backend API")
            .contact(new Contact()
                .name("Porter Support")
                .email("support@porter.com")))
        .externalDocs(new ExternalDocumentation()
            .description("Porter API Documentation")
            .url("https://docs.porter.com"));
  }
}
