#!/bin/bash
# ============================================================
# SCRIPT COMPLET — Examen Services Web ISI M2 2025-2026
# Lance depuis la racine du projet (là où sont calendar/,
# historique/ et gateway/)
# ============================================================

set -e
echo "🚀 Génération du projet complet..."

# ============================================================
# 1. MICROSERVICE CALENDAR
# ============================================================
echo ""
echo "📦 [1/3] Microservice CALENDAR..."

mkdir -p calendar/src/main/java/com/groupeisi/calendar/web/rest
mkdir -p calendar/src/main/java/com/groupeisi/calendar/config

# --- DayFinderResource.java ---
cat > calendar/src/main/java/com/groupeisi/calendar/web/rest/DayFinderResource.java << 'JAVAEOF'
package com.groupeisi.calendar.web.rest;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;

@RestController
@RequestMapping("/api")
public class DayFinderResource {

    private static final String HISTORIQUE_SAVE_URL = "http://historique/api/historique/save";

    private final RestTemplate restTemplate;

    public DayFinderResource(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @GetMapping("/dayfinder")
    public ResponseEntity<Map<String, String>> findDay(@RequestParam String date) {

        DateTimeFormatter inputFormatter = DateTimeFormatter.ofPattern("dd-MM-yyyy");
        LocalDate localDate = LocalDate.parse(date, inputFormatter);

        String dayOfWeek = getDayInFrench(localDate);
        String formattedDate = localDate.format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));

        Map<String, String> response = new LinkedHashMap<>();
        response.put("date", formattedDate);
        response.put("dayOfWeek", dayOfWeek);

        // Appel asynchrone vers historique
        try {
            Map<String, String> payload = new HashMap<>();
            payload.put("request", date);
            payload.put("responseDate", formattedDate);
            payload.put("responseDay", dayOfWeek);
            restTemplate.postForEntity(HISTORIQUE_SAVE_URL, payload, Object.class);
        } catch (Exception e) {
            System.err.println("[calendar] Erreur appel historique : " + e.getMessage());
        }

        return ResponseEntity.ok(response);
    }

    private String getDayInFrench(LocalDate date) {
        switch (date.getDayOfWeek()) {
            case MONDAY:    return "Lundi";
            case TUESDAY:   return "Mardi";
            case WEDNESDAY: return "Mercredi";
            case THURSDAY:  return "Jeudi";
            case FRIDAY:    return "Vendredi";
            case SATURDAY:  return "Samedi";
            case SUNDAY:    return "Dimanche";
            default:        return "Inconnu";
        }
    }
}
JAVAEOF

# --- RestTemplateConfig.java ---
cat > calendar/src/main/java/com/groupeisi/calendar/config/RestTemplateConfig.java << 'JAVAEOF'
package com.groupeisi.calendar.config;

import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
public class RestTemplateConfig {

    @Bean
    @LoadBalanced
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
JAVAEOF

echo "   ✅ DayFinderResource.java créé"
echo "   ✅ RestTemplateConfig.java créé"

# --- Patch SecurityConfiguration calendar ---
python3 << 'PYEOF'
import re, os

path = "calendar/src/main/java/com/groupeisi/calendar/config/SecurityConfiguration.java"
if not os.path.exists(path):
    print("   ⚠️  SecurityConfiguration.java introuvable pour calendar, skip.")
else:
    with open(path, "r") as f:
        content = f.read()

    permit_line = '.requestMatchers("/api/dayfinder").permitAll()'
    if permit_line not in content:
        # Cherche ".requestMatchers" et insère avant le premier
        content = content.replace(
            '.requestMatchers(mvc.pattern("/api/authenticate")).permitAll()',
            '.requestMatchers(mvc.pattern("/api/dayfinder")).permitAll()\n                .requestMatchers(mvc.pattern("/api/authenticate")).permitAll()',
            1
        )
        # Fallback si pattern différent
        if permit_line not in content and ".permitAll()" in content:
            content = re.sub(
                r'(\.requestMatchers\(.*?/api/authenticate.*?\.permitAll\(\))',
                r'.requestMatchers("/api/dayfinder").permitAll()\n                \1',
                content, count=1
            )
        with open(path, "w") as f:
            f.write(content)
        print("   ✅ SecurityConfiguration calendar patché")
    else:
        print("   ℹ️  SecurityConfiguration calendar déjà ok")
PYEOF

# ============================================================
# 2. MICROSERVICE HISTORIQUE
# ============================================================
echo ""
echo "📦 [2/3] Microservice HISTORIQUE..."

mkdir -p historique/src/main/java/com/groupeisi/historique/domain
mkdir -p historique/src/main/java/com/groupeisi/historique/repository
mkdir -p historique/src/main/java/com/groupeisi/historique/web/rest
mkdir -p historique/src/main/resources/config/liquibase/changelog

# --- SearchHistory.java ---
cat > historique/src/main/java/com/groupeisi/historique/domain/SearchHistory.java << 'JAVAEOF'
package com.groupeisi.historique.domain;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "search_history")
public class SearchHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "search_date")
    private Instant searchDate;

    @Column(name = "request")
    private String request;

    @Column(name = "response_date")
    private String responseDate;

    @Column(name = "response_day")
    private String responseDay;

    public SearchHistory() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Instant getSearchDate() { return searchDate; }
    public void setSearchDate(Instant searchDate) { this.searchDate = searchDate; }

    public String getRequest() { return request; }
    public void setRequest(String request) { this.request = request; }

    public String getResponseDate() { return responseDate; }
    public void setResponseDate(String responseDate) { this.responseDate = responseDate; }

    public String getResponseDay() { return responseDay; }
    public void setResponseDay(String responseDay) { this.responseDay = responseDay; }
}
JAVAEOF

# --- SearchHistoryRepository.java ---
cat > historique/src/main/java/com/groupeisi/historique/repository/SearchHistoryRepository.java << 'JAVAEOF'
package com.groupeisi.historique.repository;

import com.groupeisi.historique.domain.SearchHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SearchHistoryRepository extends JpaRepository<SearchHistory, Long> {
}
JAVAEOF

# --- SearchHistoryResource.java ---
cat > historique/src/main/java/com/groupeisi/historique/web/rest/SearchHistoryResource.java << 'JAVAEOF'
package com.groupeisi.historique.web.rest;

import com.groupeisi.historique.domain.SearchHistory;
import com.groupeisi.historique.repository.SearchHistoryRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;

@RestController
@RequestMapping("/api")
public class SearchHistoryResource {

    private final SearchHistoryRepository searchHistoryRepository;

    public SearchHistoryResource(SearchHistoryRepository searchHistoryRepository) {
        this.searchHistoryRepository = searchHistoryRepository;
    }

    // Appelé par le microservice calendar
    @PostMapping("/historique/save")
    public ResponseEntity<SearchHistory> saveHistory(@RequestBody Map<String, String> payload) {
        SearchHistory h = new SearchHistory();
        h.setSearchDate(Instant.now());
        h.setRequest(payload.get("request"));
        h.setResponseDate(payload.get("responseDate"));
        h.setResponseDay(payload.get("responseDay"));
        return ResponseEntity.ok(searchHistoryRepository.save(h));
    }

    // GET /historique/all — format imbriqué attendu par le prof
    @GetMapping("/historique/all")
    public ResponseEntity<List<Map<String, Object>>> getAllHistory() {
        List<SearchHistory> list = searchHistoryRepository.findAll();

        DateTimeFormatter fmt = DateTimeFormatter
            .ofPattern("dd/MM/yyyy HH:mm:ss")
            .withZone(ZoneId.systemDefault());

        List<Map<String, Object>> result = new ArrayList<>();
        for (SearchHistory h : list) {
            Map<String, Object> responseObj = new LinkedHashMap<>();
            responseObj.put("date", h.getResponseDate());
            responseObj.put("day", h.getResponseDay());

            Map<String, Object> searchItems = new LinkedHashMap<>();
            searchItems.put("request", h.getRequest());
            searchItems.put("response", responseObj);

            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", h.getId());
            item.put("searchDate", fmt.format(h.getSearchDate()));
            item.put("searchItems", searchItems);

            result.add(item);
        }
        return ResponseEntity.ok(result);
    }
}
JAVAEOF

# --- Liquibase changelog ---
cat > historique/src/main/resources/config/liquibase/changelog/20260523000001_create_search_history.xml << 'XMLEOF'
<?xml version="1.0" encoding="utf-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
    http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.6.xsd">

    <changeSet id="20260523000001" author="jhipster">
        <createTable tableName="search_history">
            <column name="id" type="bigint" autoIncrement="true">
                <constraints primaryKey="true" nullable="false"/>
            </column>
            <column name="search_date" type="timestamp"/>
            <column name="request" type="varchar(255)"/>
            <column name="response_date" type="varchar(255)"/>
            <column name="response_day" type="varchar(50)"/>
        </createTable>
    </changeSet>

</databaseChangeLog>
XMLEOF

# --- Ajouter changelog dans master.xml ---
python3 << 'PYEOF'
import os

master = "historique/src/main/resources/config/liquibase/master.xml"
include = '<include file="config/liquibase/changelog/20260523000001_create_search_history.xml" relativeToChangelogFile="false"/>'

if not os.path.exists(master):
    print("   ⚠️  master.xml introuvable, skip.")
else:
    with open(master, "r") as f:
        content = f.read()
    if "20260523000001" not in content:
        content = content.replace("</databaseChangeLog>", f"    {include}\n</databaseChangeLog>")
        with open(master, "w") as f:
            f.write(content)
        print("   ✅ master.xml mis à jour")
    else:
        print("   ℹ️  master.xml déjà ok")
PYEOF

# --- Patch SecurityConfiguration historique ---
python3 << 'PYEOF'
import re, os

path = "historique/src/main/java/com/groupeisi/historique/config/SecurityConfiguration.java"
if not os.path.exists(path):
    print("   ⚠️  SecurityConfiguration.java introuvable pour historique, skip.")
else:
    with open(path, "r") as f:
        content = f.read()

    if '/api/historique' not in content:
        content = content.replace(
            '.requestMatchers(mvc.pattern("/api/authenticate")).permitAll()',
            '.requestMatchers(mvc.pattern("/api/historique/**")).permitAll()\n                .requestMatchers(mvc.pattern("/api/authenticate")).permitAll()',
            1
        )
        with open(path, "w") as f:
            f.write(content)
        print("   ✅ SecurityConfiguration historique patché")
    else:
        print("   ℹ️  SecurityConfiguration historique déjà ok")
PYEOF

echo "   ✅ SearchHistory.java créé"
echo "   ✅ SearchHistoryRepository.java créé"
echo "   ✅ SearchHistoryResource.java créé"
echo "   ✅ Liquibase changelog créé"

# ============================================================
# 3. GATEWAY — Routes
# ============================================================
echo ""
echo "📦 [3/3] GATEWAY — Injection des routes..."

python3 << 'PYEOF'
import os, re

path = "gateway/src/main/resources/config/application.yml"
if not os.path.exists(path):
    print("   ⚠️  application.yml gateway introuvable, skip.")
else:
    with open(path, "r") as f:
        content = f.read()

    routes_block = """
      routes:
        - id: calendar
          uri: lb://calendar
          predicates:
            - Path=/services/calendar/**
          filters:
            - RewritePath=/services/calendar/(?<seg>.*), /api/$\\{seg}
        - id: historique
          uri: lb://historique
          predicates:
            - Path=/historique/**
          filters:
            - RewritePath=/historique/(?<seg>.*), /api/historique/$\\{seg}
"""

    if "lb://calendar" not in content:
        # Cherche "gateway:" et insère les routes après
        if "gateway:" in content:
            content = content.replace("gateway:", "gateway:" + routes_block, 1)
        else:
            content += "\nspring:\n  cloud:\n    gateway:" + routes_block

        with open(path, "w") as f:
            f.write(content)
        print("   ✅ Routes gateway injectées")
    else:
        print("   ℹ️  Routes gateway déjà présentes")
PYEOF

# ============================================================
# 4. GIT PUSH
# ============================================================
echo ""
echo "🔧 Préparation Git..."
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
git add . 2>/dev/null || true
git commit -m "feat: logique metier complete - dayfinder + historique" 2>/dev/null || echo "   ℹ️  Rien à committer ou git non initialisé ici"
git push origin main 2>/dev/null || git push origin master 2>/dev/null || echo "   ⚠️  Push manuel nécessaire : git push origin main"

echo ""
echo "=============================================="
echo "✅ PROJET COMPLET GÉNÉRÉ !"
echo "=============================================="
echo ""
echo "📋 URLs à tester après démarrage :"
echo ""
echo "  DAY FINDER :"
echo "  curl 'http://localhost:8080/services/calendar/dayfinder?date=22-01-1945'"
echo "  Attendu : {\"date\":\"22/01/1945\",\"dayOfWeek\":\"Lundi\"}"
echo ""
echo "  HISTORIQUE :"
echo "  curl 'http://localhost:8080/historique/all'"
echo "  Attendu : [{\"id\":1,\"searchDate\":\"...\",\"searchItems\":{...}}]"
echo ""
echo "📋 Ordre de démarrage :"
echo "  1. JHipster Registry"
echo "  2. mvn -f historique/pom.xml spring-boot:run"
echo "  3. mvn -f calendar/pom.xml spring-boot:run"
echo "  4. mvn -f gateway/pom.xml spring-boot:run"
echo ""
