import javafx.application.Application;
import javafx.scene.Scene;
import javafx.scene.control.Label;
import javafx.scene.layout.StackPane;
import javafx.stage.Stage;

public class MainApp extends Application {

    @Override
    public void start(Stage primaryStage) {
        // Einfacher Test: Ein Label im Fenster
        Label label = new Label("Hello LoRa World!");
        StackPane root = new StackPane(label);

        Scene scene = new Scene(root, 400, 200);
        primaryStage.setTitle("LoRa Test App");
        primaryStage.setScene(scene);
        primaryStage.show();
    }

    public static void main(String[] args) {
        launch(args); // Startet die JavaFX-App
    }
}
