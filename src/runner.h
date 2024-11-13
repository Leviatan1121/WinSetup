#ifndef RUNNER_H
#define RUNNER_H

#include <stdio.h>
#include <windows.h>

#define NUM_COMMANDS 3  // Número de comandos disponibles

typedef struct {
    HWND hwnd;                   // Handle de la ventana principal
    HINSTANCE hInstance;         // Instance de la aplicación
    HWND buttons[NUM_COMMANDS];  // Arreglo de handles de botones
} App;

// Estructura para pasar parámetros a la función del hilo
typedef struct {
    App *app;         // Puntero a la estructura App
    int buttonIndex;  // Índice del botón
} ThreadParams;

void DrawUI(App *app);
void Options(App *app, WPARAM wParam);

#endif