package co.za.hlaluko.dynamics.poultry.pal;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import org.junit.jupiter.api.Test;
import org.springframework.core.env.PropertiesPropertySource;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.support.PropertiesLoaderUtils;
import org.springframework.mock.env.MockEnvironment;

class TlsConfigurationTest {

  private MockEnvironment environment() throws IOException {
    MockEnvironment environment = new MockEnvironment();
    environment
        .getPropertySources()
        .addLast(
            new PropertiesPropertySource(
                "application",
                PropertiesLoaderUtils.loadProperties(
                    new ClassPathResource("application.properties"))));
    return environment;
  }

  @Test
  void defaultsToHttpsAndSecureCookies() throws IOException {
    MockEnvironment environment = environment();

    assertThat(environment.getProperty("server.ssl.enabled", Boolean.class)).isTrue();
    assertThat(environment.getProperty("poultry.pal.app.cookie.secure", Boolean.class)).isTrue();
    assertThat(environment.getProperty("server.ssl.key-store"))
        .isEqualTo("classpath:keystore/keystore.p12");
    assertThat(environment.getProperty("server.ssl.key-alias")).isEqualTo("tomcat");
  }

  @Test
  void oneSwitchRestoresHttpAndNonSecureCookies() throws IOException {
    MockEnvironment environment = environment().withProperty("TLS_ENABLED", "false");

    assertThat(environment.getProperty("server.ssl.enabled", Boolean.class)).isFalse();
    assertThat(environment.getProperty("poultry.pal.app.cookie.secure", Boolean.class)).isFalse();
  }

  @Test
  void explicitCookieOverrideSupportsExternalTlsTermination() throws IOException {
    MockEnvironment environment =
        environment().withProperty("TLS_ENABLED", "false").withProperty("COOKIE_SECURE", "true");

    assertThat(environment.getProperty("server.ssl.enabled", Boolean.class)).isFalse();
    assertThat(environment.getProperty("poultry.pal.app.cookie.secure", Boolean.class)).isTrue();
  }
}
