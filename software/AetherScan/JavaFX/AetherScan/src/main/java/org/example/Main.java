package org.example;

import javafx.application.Application;
import javafx.scene.Scene;
import javafx.scene.control.Label;
import javafx.scene.layout.StackPane;
import javafx.stage.Stage;

public class MainApp extends Application {
    @Override
    public void start(Stage primaryStage) {
        Label label = new Label("Hello LoRa World!"); // Test-Label
        StackPane root = new StackPane(label);
        Scene scene = new Scene(root, 400, 200);
        primaryStage.setTitle("LoRa-Scope Test");
        primaryStage.setScene(scene);
        primaryStage.show();
    }

    public static void main(String[] args) {
        launch(args);
    }
}
