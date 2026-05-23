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

    // URL load-balancée vers le microservice historique via Eureka
    private static final String HISTORIQUE_SAVE_URL = "http://historique/api/historique/save";

    private final RestTemplate restTemplate;

    public DayFinderResource(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @GetMapping("/dayfinder")   // ← CORRIGÉ : était /calendar/dayfinder
    public ResponseEntity<Map<String, String>> findDay(@RequestParam String date) {

        DateTimeFormatter inputFormatter = DateTimeFormatter.ofPattern("dd-MM-yyyy");
        LocalDate localDate = LocalDate.parse(date, inputFormatter);

        String dayOfWeek = getDayInFrench(localDate);
        String formattedDate = localDate.format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));

        Map<String, String> response = new LinkedHashMap<>();
        response.put("date", formattedDate);
        response.put("dayOfWeek", dayOfWeek);

        // ← AJOUT : sauvegarde dans historique
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