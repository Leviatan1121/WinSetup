#include "runner.h"

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

// Función para comprobar si ya hay una instancia de la aplicación
BOOL CheckSingleInstance() {
    HANDLE hMutex = CreateMutex(NULL, TRUE, "WinSetup_single_instance");
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        MessageBox(NULL, "Only one instance is allowed to run at the same time.", "Error", MB_ICONERROR);
        return FALSE;
    }
    return TRUE;
}

// Función para inicializar y registrar la ventana
void InitWindow(App *app, HINSTANCE hInstance, int nShowCmd) {
    const char CLASS_NAME[] = "WinSetup";

    WNDCLASS wc = {0};
    wc.lpfnWndProc = WindowProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;

    RegisterClass(&wc);

    // Tamaño de la pantalla
    const int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    const int screenHeight = GetSystemMetrics(SM_CYSCREEN);

    // Tamaño mínimo de la ventana
    const int MIN_WIDTH = 300;
    const int MIN_HEIGHT = 200;

    // Tamaño calculado de la ventana
    int windowWidth = screenWidth / 2;
    int windowHeight = screenHeight / 2;
    if (windowWidth < MIN_WIDTH || windowHeight < MIN_HEIGHT) {
        windowWidth = MIN_WIDTH;
        windowHeight = MIN_HEIGHT;
    } else if (windowHeight > windowWidth) {
        windowHeight = windowWidth / 3 * 2;
    }

    // Centrar la ventana
    const int posX = (screenWidth / 2) - (windowWidth / 2);
    const int posY = (screenHeight / 2) - (windowHeight / 2);

    // Creación de la ventana
    app->hwnd = CreateWindowEx(0, CLASS_NAME, "WinSetup", WS_OVERLAPPEDWINDOW,
                               posX, posY, windowWidth, windowHeight, NULL, NULL, hInstance, NULL);

    // Guardamos el puntero a la estructura 'App' en la ventana
    SetWindowLongPtr(app->hwnd, GWLP_USERDATA, (LONG_PTR)app);

    ShowWindow(app->hwnd, nShowCmd);
    UpdateWindow(app->hwnd);
}

// Main menu
LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    App *app = (App *)GetWindowLongPtr(hwnd, GWLP_USERDATA);  // Obtener la estructura App

    switch (uMsg) {
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        case WM_COMMAND:
            if (app != NULL) {
                Options(app, wParam);  // Pasar 'app' a la función 'Options'
            } else {
                MessageBox(NULL, "WM_COMMAND failed.", "Error", MB_ICONERROR);
            }
            return 0;
    }
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

// Función principal que maneja el bucle de mensajes
void RunMessageLoop() {
    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE, LPSTR, int nShowCmd) {
    if (!CheckSingleInstance()) {
        return 0;  // Si ya hay una instancia, salimos.
    }

    App app;
    app.hInstance = hInstance;

    InitWindow(&app, hInstance, nShowCmd);
    DrawUI(&app);
    RunMessageLoop();

    return 0;
}