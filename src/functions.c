#include "runner.h"

// Función auxiliar para crear botones dinámicamente
void AddButton(App *app, const char *text, int x, int y, int id, int index, SIZE textSize) {
    app->buttons[index] = CreateWindow(
        "BUTTON", text, WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_DEFPUSHBUTTON,
        x, y, textSize.cx, textSize.cy, app->hwnd, (HMENU)(UINT_PTR)id, app->hInstance, NULL);
}

typedef struct {
    int width;
    int height;
} Window;
Window getWindowSize(HWND hwnd) {
    RECT rect;
    GetClientRect(hwnd, &rect);  // Obtener el tamaño del área cliente
    return (Window){
        rect.right > rect.left ? rect.right : rect.left,
        rect.bottom > rect.top ? rect.bottom : rect.top,
    };
}

SIZE getTextSize(App *app, char *text) {
    HDC hdc = GetDC(app->hwnd);  // Obtener el contexto del dispositivo
    SIZE size;
    GetTextExtentPoint32(hdc, text, strlen(text), &size);  // Calcular el tamaño del texto
    ReleaseDC(app->hwnd, hdc);                             // Liberar el contexto del dispositivo
    size.cx += 10;
    return size;
}

void AddText(App *app, char *text, SIZE size, int x, int y) {
    CreateWindow(
        "STATIC",                           // Clase de ventana
        text,                               // Texto que se mostrará
        WS_VISIBLE | WS_CHILD | SS_CENTER,  // Estilos de ventana
        x, y,                               // Posición calculada
        size.cx, size.cy,                   // Tamaño (ancho, alto)
        app->hwnd,                          // Ventana padre
        NULL,                               // Sin menú
        app->hInstance,                     // Instancia de la aplicación
        NULL                                // Sin datos adicionales
    );
}

//* UI
void DrawUI(App *app) {
    Window win = getWindowSize(app->hwnd);

    char *text = "An internet connection";  // Texto que se mostrará
    SIZE textSize = getTextSize(app, text);
    int posX = win.width / 2 - textSize.cx / 2;
    int posY = 5;

    AddText(app, text, textSize, posX, posY);
    posY += textSize.cy;
    AddText(app, "or elevated rights", textSize, posX, posY);
    posY += textSize.cy;
    AddText(app, "may be required.", textSize, posX, posY);
    posY += textSize.cy + 5;
    AddText(app, "TEST", textSize, posX, posY);

    textSize = getTextSize(app, "Install Filelight, Wintoys && Wub");
    textSize.cy = textSize.cy + 10;
    posX = win.width / 2 - textSize.cx / 2;
    AddButton(app, "Install Filelight, Wintoys && Wub", posX, posY, 1, 0, textSize);
    posY += textSize.cy;
    AddButton(app, "Windows Utility Toolbox", posX, posY, 2, 1, textSize);
    posY += textSize.cy;
    AddButton(app, "Tweak Windows", posX, posY, 3, 2, textSize);
}

BOOL checkNetwork() {
    if (system("ping -n 1 8.8.8.8") == 0) return TRUE;
    return FALSE;
}

//* Comandos
const char *commands[NUM_COMMANDS] = {
    "cmd /c echo %USERPROFILE%\\Desktop & pause",  // Comando para el botón 1
    "wmic bios get serialnumber & pause",          // Comando para el botón 2
    "control panel"                                // Comando para el botón 3
};

// Función del hilo que ejecuta el comando
DWORD WINAPI RunCommand(LPVOID lpParam) {
    ThreadParams *params = (ThreadParams *)lpParam;  // Obtener los parámetros
    const BOOL network = checkNetwork();             // Check network
    const int option = params->buttonIndex;

    switch (option + 1) {
        case 1:
            if (!network)
                MessageBox(NULL, "Check your internet connection and try again.", "Error", MB_ICONERROR);
            else {
                system(
                    "echo Installing Filelight:"
                    "& powershell -C \"winget install -e --silent --accept-source-agreements --accept-package-agreements --name Filelight\""
                    "& echo: & echo Installing Wintoys:"
                    "& powershell -C \"winget install -e --silent --accept-source-agreements --accept-package-agreements --name Wintoys\""
                    "& echo: & echo Downloading Windows Update Blocker (Wub):"
                    "& del WinSetup_WubPackage.zip 2>nul & rmdir /S /Q WinSetup_WubPackage \"Windows Update Blocker\" 2>nul"
                    "& powershell -C \"Invoke-WebRequest 'https://www.sordum.org/files/downloads.php?st-windows-update-blocker' -OutFile '.\\WinSetup_WubPackage.zip';Expand-Archive -LiteralPath '.\\WinSetup_WubPackage.zip' -DestinationPath '.\\WinSetup_WubPackage';Move-Item -Path '.\\WinSetup_WubPackage\\Wub' -Destination '.\\Windows Update Blocker';rm '.\\WinSetup_WubPackage*' -force\""
                    "& echo: & echo Finished. & timeout /t 3");
            }
            break;
        case 2:
            if (!network)
                MessageBox(NULL, "Check your internet connection and try again.", "Error", MB_ICONERROR);
            else {
                system(
                    "echo Please wait, this can take a few seconds. &"
                    "(echo|set /p=\"Chris Titus Tech's Windows Utility Toolbox now loading"
                    "\") & timeout /t 1 >nul & (for /L %i in (1,1,3) do @set /p=\".\" <nul & timeout /t 1 >nul) & echo( "
                    "& powershell -C \"Start-Process "                              // start process from powershell
                    "'powershell.exe' 'irm https://www.christitus.com/win | iex' "  // command as admin
                    "-Verb RunAs "                                                  // force admin
                    "-Wait "                                                        // tell system to wait until finished
                    "-WindowStyle Hidden\"");                                       // we avoid displaying extra cli
            }
            break;
        case 4:
            system("echo Nothing to see here yet. & timeout /t 3");
            break;
        default:
            // Ejecutar el comando asociado al índice
            system(commands[option]);
            break;
    }

    // Habilitar el botón correspondiente
    EnableWindow(params->app->buttons[option], TRUE);

    // Liberar la memoria de los parámetros del hilo
    free(params);

    return 0;
}

// Menu options
void Options(App *app, WPARAM wParam) {
    int buttonIndex = LOWORD(wParam) - 1;  // Ajustar el índice para el array (0, 1, 2)

    if (buttonIndex >= 0 && buttonIndex < NUM_COMMANDS) {
        EnableWindow(app->buttons[buttonIndex], FALSE);  // Deshabilitar el botón

        // Crear los parámetros para el hilo
        ThreadParams *params = malloc(sizeof(ThreadParams));
        params->app = app;
        params->buttonIndex = buttonIndex;

        // Crear el hilo para ejecutar el comando, pasando los parámetros
        CreateThread(NULL, 0, RunCommand, (LPVOID)params, 0, NULL);
    }
}