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

    // Getters et Setters
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