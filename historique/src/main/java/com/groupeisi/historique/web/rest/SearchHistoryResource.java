package com.groupeisi.historique.web.rest;

import com.groupeisi.historique.domain.SearchHistory;
import com.groupeisi.historique.repository.SearchHistoryRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@RestController
@RequestMapping("/api")
public class SearchHistoryResource {

    private final SearchHistoryRepository searchHistoryRepository;

    public SearchHistoryResource(SearchHistoryRepository searchHistoryRepository) {
        this.searchHistoryRepository = searchHistoryRepository;
    }

    // GET /historique/all → retourne tout l'historique
    @GetMapping("/historique/all")
    public ResponseEntity<List<SearchHistory>> getAllHistory() {
        List<SearchHistory> history = searchHistoryRepository.findAll();
        return ResponseEntity.ok(history);
    }

    // POST /historique/save → sauvegarde une entrée (appelé par calendar)
    @PostMapping("/historique/save")
    public ResponseEntity<SearchHistory> saveHistory(@RequestBody SearchHistory searchHistory) {
        searchHistory.setSearchDate(Instant.now());
        SearchHistory saved = searchHistoryRepository.save(searchHistory);
        return ResponseEntity.ok(saved);
    }
}
