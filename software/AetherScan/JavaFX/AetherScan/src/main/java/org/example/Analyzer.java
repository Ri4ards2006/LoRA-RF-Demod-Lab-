package org.example;

import javafx.animation.FadeTransition;
import javafx.application.Application;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.chart.LineChart;
import javafx.scene.chart.NumberAxis;
import javafx.scene.chart.XYChart;
import javafx.scene.control.*;
import javafx.scene.effect.DropShadow;
import javafx.scene.layout.*;
import javafx.scene.paint.Color;
import javafx.scene.text.Font;
import javafx.stage.Stage;
import javafx.util.Duration;

import java.util.Random;

/**
 * AetherScan Analyzer – All-in-One Demo App
 * -----------------------------------------
 * Features:
 *  - Sidebar Navigation
 *  - Signal Analyzer (Chart)
 *  - Serial Monitor
 *  - Dashboard Overview
 *  - Settings Panel
 *  - Dark UI Theme
 */
public class Analyzer extends Application {

    private BorderPane root;
    private VBox sidebar;
    private StackPane contentPane;

    @Override
    public void start(Stage stage) {
        root = new BorderPane();
        sidebar = createSidebar();
        contentPane = new StackPane();

        // Start mit Dashboard
        contentPane.getChildren().add(createDashboard());

        root.setLeft(sidebar);
        root.setCenter(contentPane);

        Scene scene = new Scene(root, 1000, 600);
        scene.getStylesheets().add("https://fonts.googleapis.com/css2?family=JetBrains+Mono&display=swap");
        root.setStyle("-fx-background-color: #1E1E2E;");

        stage.setTitle("AetherScan – LoRa Analyzer");
        stage.setScene(scene);
        stage.show();
    }

    private VBox createSidebar() {
        VBox box = new VBox(20);
        box.setPadding(new Insets(20));
        box.setStyle("-fx-background-color: #2E2E3E;");
        box.setPrefWidth(200);

        Label title = new Label("AetherScan");
        title.setTextFill(Color.WHITE);
        title.setFont(Font.font("JetBrains Mono", 22));

        Button dashBtn = createSidebarButton("🏠 Dashboard", () -> switchContent(createDashboard()));
        Button signalBtn = createSidebarButton("📶 Analyzer", () -> switchContent(createAnalyzerView()));
        Button serialBtn = createSidebarButton("🧭 Serial Monitor", () -> switchContent(createSerialMonitor()));
        Button settingsBtn = createSidebarButton("⚙️ Settings", () -> switchContent(createSettings()));

        Region spacer = new Region();
        VBox.setVgrow(spacer, Priority.ALWAYS);

        Label footer = new Label("v1.0 | Richard");
        footer.setTextFill(Color.GRAY);
        footer.setFont(Font.font("JetBrains Mono", 12));

        box.getChildren().addAll(title, dashBtn, signalBtn, serialBtn, settingsBtn, spacer, footer);
        return box;
    }

    private Button createSidebarButton(String text, Runnable action) {
        Button btn = new Button(text);
        btn.setPrefWidth(160);
        btn.setAlignment(Pos.CENTER_LEFT);
        btn.setFont(Font.font("JetBrains Mono", 14));
        btn.setTextFill(Color.WHITE);
        btn.setStyle("-fx-background-color: transparent;");
        btn.setOnMouseEntered(e -> btn.setStyle("-fx-background-color: #44445A;"));
        btn.setOnMouseExited(e -> btn.setStyle("-fx-background-color: transparent;"));
        btn.setOnAction(e -> action.run());
        return btn;
    }

    private void switchContent(Pane newContent) {
        FadeTransition fadeOut = new FadeTransition(Duration.millis(200), contentPane);
        fadeOut.setFromValue(1);
        fadeOut.setToValue(0);
        fadeOut.setOnFinished(e -> {
            contentPane.getChildren().setAll(newContent);
            FadeTransition fadeIn = new FadeTransition(Duration.millis(200), contentPane);
            fadeIn.setFromValue(0);
            fadeIn.setToValue(1);
            fadeIn.play();
        });
        fadeOut.play();
    }

    private Pane createDashboard() {
        VBox box = new VBox(15);
        box.setAlignment(Pos.CENTER);
        box.setPadding(new Insets(30));

        Label title = new Label("📊 System Overview");
        title.setTextFill(Color.WHITE);
        title.setFont(Font.font("JetBrains Mono", 24));

        Label info = new Label("Connected Device: LoRa RX v2.1\nSignal Status: Stable\nLast Sync: Just now");
        info.setTextFill(Color.LIGHTGRAY);
        info.setFont(Font.font("JetBrains Mono", 16));

        box.getChildren().addAll(title, info);
        return box;
    }

    private Pane createAnalyzerView() {
        VBox box = new VBox(15);
        box.setPadding(new Insets(20));
        box.setAlignment(Pos.TOP_CENTER);

        Label title = new Label("📶 Signal Analyzer");
        title.setTextFill(Color.WHITE);
        title.setFont(Font.font("JetBrains Mono", 22));

        NumberAxis xAxis = new NumberAxis();
        NumberAxis yAxis = new NumberAxis();
        xAxis.setLabel("Time (s)");
        yAxis.setLabel("Signal Strength (dB)");

        LineChart<Number, Number> chart = new LineChart<>(xAxis, yAxis);
        chart.setLegendVisible(false);
        chart.setPrefHeight(400);
        chart.setStyle("-fx-background-color: #252537; -fx-text-fill: white;");

        XYChart.Series<Number, Number> series = new XYChart.Series<>();
        Random random = new Random();
        for (int i = 0; i < 50; i++) {
            series.getData().add(new XYChart.Data<>(i, 70 + random.nextGaussian() * 5));
        }
        chart.getData().add(series);

        Button refresh = new Button("🔄 Refresh Data");
        refresh.setFont(Font.font("JetBrains Mono", 14));
        refresh.setOnAction(e -> {
            series.getData().clear();
            for (int i = 0; i < 50; i++) {
                series.getData().add(new XYChart.Data<>(i, 70 + random.nextGaussian() * 5));
            }
        });

        box.getChildren().addAll(title, chart, refresh);
        return box;
    }

    private Pane createSerialMonitor() {
        VBox box = new VBox(10);
        box.setPadding(new Insets(20));

        Label title = new Label("🧭 Serial Monitor");
        title.setTextFill(Color.WHITE);
        title.setFont(Font.font("JetBrains Mono", 20));

        TextArea area = new TextArea();
        area.setPromptText("Incoming serial data...");
        area.setStyle("-fx-control-inner-background:#1B1B2B; -fx-text-fill:white;");
        area.setPrefHeight(400);

        Button send = new Button("Send Command");
        send.setOnAction(e -> area.appendText("\n> Command sent @ " + System.currentTimeMillis()));
        send.setFont(Font.font("JetBrains Mono", 14));

        box.getChildren().addAll(title, area, send);
        return box;
    }

    private Pane createSettings() {
        VBox box = new VBox(15);
        box.setPadding(new Insets(20));

        Label title = new Label("⚙️ Settings");
        title.setTextFill(Color.WHITE);
        title.setFont(Font.font("JetBrains Mono", 20));

        CheckBox darkMode = new CheckBox("Dark Mode");
        darkMode.setSelected(true);
        darkMode.setTextFill(Color.WHITE);

        Slider brightness = new Slider(0, 100, 75);
        Label brightLabel = new Label("Brightness: 75%");
        brightLabel.setTextFill(Color.LIGHTGRAY);
        brightness.valueProperty().addListener((obs, oldVal, newVal) ->
                brightLabel.setText("Brightness: " + newVal.intValue() + "%"));

        box.getChildren().addAll(title, darkMode, brightLabel, brightness);
        return box;
    }

    public static void main(String[] args) {
        launch(args);
    }
}
