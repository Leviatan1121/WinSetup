# Windows installation

Para evitar cuenta Microsoft en el OOBE, abre consola con `Shift + F10`:

```cmd
OOBE\BYPASSNRO
```

o:

```cmd
start ms-cxh:localonly
```

**Actualiza Windows después de instalar** (antes de ejecutar WinSetup, si es posible).

---

# WinSetup — documentación y checklist

Descarga y ejecuta [Setup.bat](https://github.com/Leviatan1121/WinSetup/releases/latest/download/Setup.bat).

Al terminar Setup.bat pide **cerrar sesión o reiniciar** para que el preset de rendimiento se refleje en `sysdm.cpl`. Tras el **primer reinicio real** se abren automáticamente:

1. **Ajustes → Puntero del mouse** (elegir color).
2. **InstallApps** (selector gráfico de software).

---

## Orden de ejecución (Setup.bat)

| # | Fase | Admin | Script / acción |
|---|------|-------|-----------------|
| 0 | Helpers de usuario | No | Crea `%USERPROFILE%\bin`, añade al PATH, `AllowFile.bat` / `AllowProcess.bat` |
| 1 | Windows Update Pauser | No | Descarga y ejecuta [WindowsUpdatePauser](https://github.com/Leviatan1121/WindowsUpdatePauser) |
| 2 | Descarga de scripts | No | Release de GitHub → `%TEMP%\WinSetup` |
| 3 | Configure | No | `Configure.ps1` |
| 4 | Privacy | No | `Privacy.ps1` |
| 5 | Performance (usuario) | No | `Performance.ps1` |
| 6 | Debloat + Performance (sistema) | **Sí (UAC 1)** | `Setup-Elevated.ps1` → `Debloat.ps1` + `Performance.ps1 -SystemOnly` |
| 7 | Remove Windows AI | **Sí (UAC 2)** | Script externo [zoicware/RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI) |
| 8 | Remote support | **Sí (UAC 3)** | `RemoteSupport.ps1` (opcional, interactivo) |
| 9 | Hooks post-reboot | No | Registra puntero del mouse + InstallApps en `HKCU\...\Run` |
| 10 | Limpieza | No | Borra `%TEMP%\WinSetup` |

---

## 1. Windows Update Pauser

Pausa actualizaciones de Windows durante el setup (herramienta externa).

**Comprobar:** que las actualizaciones no se instalen solas mientras configuras el PC.

---

## 2. Helpers de entorno (`%USERPROFILE%\bin`)

| Elemento | Qué hace |
|----------|----------|
| `%USERPROFILE%\bin` | Carpeta en PATH de usuario |
| `AllowFile.bat` | Ejecuta un `.ps1` con bypass de política |
| `AllowProcess.bat` | Abre PowerShell interactivo con bypass |

---

## 3. Configure (`Configure.ps1`) — HKCU, sin admin

### Accesibilidad → Puntero del mouse y movimiento
- Tamaño del puntero: **3** (grande).
- `CursorBaseSize` = 64.
- **Sin aceleración del mouse** (`MouseSpeed` y umbrales a 0).
- El **color del puntero** no se fija aquí; se elige tras el reinicio (hook post-reboot).

### Personalización → Temas
- Aplica tema **oscuro** (`dark.theme`).

### Sistema → Opciones de desarrollador
- **Finalizar tarea** en la barra de tareas: activado.

### Multitarea → Alt + Tab
- Solo **ventanas abiertas** (sin pestañas del navegador como entradas separadas).

### Explorador de archivos → Ver
- **Extensiones de archivo visibles**.
- **Archivos ocultos visibles**.
- Abrir en **Este equipo** (no Inicio rápido).
- **Desanclar Inicio y Galería** del panel de navegación.
- **Elimina carpetas** del perfil si existen: `Contacts`, `Favorites`, `Links`, `Saved Games`, `Searches`.

### Barra de tareas
- **Sin cuadro de búsqueda** en la barra.
- Bing / Cortana en búsqueda: desactivado.
- Ubicación en búsqueda: desactivado.
- En **varios monitores**: iconos solo en el monitor donde está la ventana.
- **Ocultar barra de tareas** automáticamente (todos los monitores).

### Inicio
- Vista de todas las apps.
- Sin lista de recientes / frecuentes.
- Carpetas junto al botón de encendido: **Configuración**, **Explorador de archivos**, **Carpeta personal**.
- Sin recomendaciones de Iris / programas / documentos recientes.
- Content Delivery Manager: desactiva sugerencias, apps preinstaladas, Spotlight en pantalla de bloqueo, etc.
- Búsqueda en Inicio: **solo local** (sin nube MSA/AAD).

### Sistema → Energía
- Apagar pantalla: **3 minutos** (conectado y batería).
- Suspender: **nunca** (conectado y batería).

**Comprobar en Ajustes:** Apariencia, Explorador, Barra de tareas, Inicio, Energía, Puntero (tamaño; color tras reinicio).

---

## 4. Privacy (`Privacy.ps1`) — HKCU, sin admin

### Privacidad → General
- Ofertas personalizadas: **Off**.
- Experiencias personalizadas con datos de diagnóstico: **Off**.
- No compartir lista de idiomas con sitios web.
- Notificaciones de cuenta en Ajustes: **Off**.
- ID de publicidad: **Off**.

### Privacidad → Ubicación (usuario)
- Consentimiento de ubicación: **Denegar** (apps empaquetadas y de escritorio).
- Sin avisos globales de ubicación.
- *La ubicación a nivel sistema se apaga en Debloat (admin).*

### Sistema → Portapapeles
- Historial local: **On**.
- Sincronización en la nube: **Off**.

### Diagnóstico y actividad (usuario)
- No publicar actividades del usuario.
- Sin encuestas de experiencia (SIUF).
- Sin recopilación implícita de tinta/texto.
- Sin cosecha de contactos para personalización de entrada.

**Comprobar en Ajustes:** Privacidad y seguridad → General, Ubicación, Portapapeles, Diagnóstico.

---

## 5. Performance (`Performance.ps1`) — HKCU + HKLM

### Parte usuario (sin admin) — `sysdm.cpl` + Accesibilidad

Preset **Personalizado** equivalente a:
- Base **mejor rendimiento**.
- **Miniaturas** en Explorador: On.
- **ClearType** (suavizado de fuentes): On.
- **Efectos de transparencia**: Off.
- **Efectos de animación**: Off.
- Sin animaciones de barra de tareas, sombras de lista, Aero Peek, etc.

### Gaming (usuario)
- **Game DVR / captura en segundo plano**: Off.
- **Modo de juego automático**: Off.
- **Game Bar (Win+G)**: se mantiene disponible.

### Parte sistema (admin, en Setup-Elevated)
- Prioridad de primer plano: `Win32PrioritySeparation` = 38 (favorece programas).
- MMCSS `SystemResponsiveness` = 0, `NetworkThrottlingIndex` = máximo.
- Política Game DVR (HKLM): desactivado.

**Comprobar:** `sysdm.cpl` → Opciones avanzadas → Rendimiento → **Personalizado** (tras **cerrar sesión**). Accesibilidad → Efectos visuales. Configuración → Juego → capturas en segundo plano Off.

---

## 6. Debloat (`Debloat.ps1`) — admin

### Energía
- **Inicio rápido (hiberboot)**: desactivado.

### Ubicación (sistema)
- Servicios de ubicación **Off** vía `SystemSettingsAdminFlows`, políticas HKLM y consent store.
- Borra cachés SQLite de Capability Access Manager y reinicia `lfsvc` / `camsvc`.

### Barra de tareas → Widgets
- Widgets ocultos (`TaskbarDa` = 0).
- Política: sin News and Interests.
- Desinstala **Web Experience Pack** y **Widgets Platform Runtime**.

### Copilot y Recall
- Botón Copilot en barra: oculto.
- Políticas HKLM/HKCU: Copilot off, quitar app Copilot, sin análisis de datos IA.
- Recall: sin habilitación ni guardado de instantáneas.
- Desinstala paquetes Copilot y carpeta `%USERPROFILE%\.copilot`.

### OneDrive
- Desinstala OneDrive (winget + setup oficial).
- Política: bloquear sincronización / reinstalación.
- Elimina carpeta `%USERPROFILE%\OneDrive` si existe.

### Apps preinstaladas eliminadas

Feedback Hub, Weather, Phone Link, Family Safety, Get Started, Journal, Microsoft 365 Copilot (Office Hub), Clipchamp, Teams (todas las variantes), To Do, Whiteboard, Sticky Notes, News, Bing Search, Dev Home, Power Automate Desktop, Outlook, Mobile Plans, Solitaire, **WhatsApp** (todas las vías), Bing app, y otros IDs winget asociados.

### Apps que **NO** se eliminan (intencional)
- Ecosistema **Xbox**: Game Bar (Win+G), Xbox app, Identity Provider, Gaming Services, etc.

### Barra de tareas
- **Desancla todas las apps** fijadas (todos los perfiles, incluido `Default`).

### Menú Inicio
- **`start2.bin` vacío** para todos los usuarios (layout limpio; preferencias HKCU en Configure).

### Búsqueda (sistema)
- Sin resultados web/Bing en búsqueda (políticas HKLM).

### Experiencia de consumidor / Spotlight
- Sin sugerencias de apps de Store, Spotlight en bloqueo/acción/configuración, sugerencias de terceros.

### Alias de Python de Microsoft Store
- Elimina `python.exe` y `python3.exe` de `WindowsApps` (reparse points) en **todos los perfiles**.
- Evita que `python` abra la Store en lugar de mise/Python real.

### Telemetría (sistema)
- `AllowTelemetry` / `MaxTelemetryAllowed` = 0.
- Sin descargas OneSettings, sin notificaciones de feedback.
- Activity feed / upload de actividades: off.
- Servicios **DiagTrack** y **dmwappushservice**: deshabilitados y detenidos.

### Windows Update → Optimización de distribución
- Solo HTTP; sin caché P2P ni subida a otros PCs.

### Al final
- Reinicia **Explorer** y StartMenuExperienceHost.

**Comprobar:** apps eliminadas no aparecen en Inicio; sin widgets; sin Copilot; sin OneDrive; búsqueda sin web; `python` no abre Store; telemetría mínima en Políticas.

---

## 7. Remove Windows AI (externo, admin)

Script de terceros que elimina componentes de IA de Windows (complementa Debloat).

**Comprobar:** que Copilot / Recall / funciones IA no reaparezcan según lo esperado en tu build.

---

## 8. Remote support (`RemoteSupport.ps1`) — admin, interactivo

Pregunta **Enter = Sí** para desinstalar:

| Herramienta | Notas |
|-------------|--------|
| **Quick Assist** | Appx + capability de Windows |
| **Conexión a Escritorio remoto** (`mstsc`) | Puede pedir **reinicio** al finalizar |

Si pulsas cualquier otra tecla, se omite.

---

## 9. Tras Setup.bat — antes del reinicio

Mensajes finales indican:
- Cerrar sesión o reiniciar (rendimiento en `sysdm.cpl`).
- Tras reinicio: puntero del mouse + InstallApps.

Archivos persistentes hasta el post-reboot:

| Ruta | Uso |
|------|-----|
| `%LOCALAPPDATA%\WinSetup\` | Scripts y marcadores temporales |
| `HKCU\...\Run\WinSetup-MousePointerSettings` | Abre ajustes del puntero tras reinicio |
| `HKCU\...\Run\WinSetup-InstallApps` | Lanza InstallApps tras reinicio |

---

## 10. Post-reboot — Puntero del mouse

1. Compara `LastBootUpTime` con el marcador `.open-mouse-after-reboot` (reinicio real, no solo reinicio de Explorer).
2. Abre `ms-settings:easeofaccess-mousepointer`.
3. Elimina hook, marcador y el script copiado.

**Comprobar:** elige el **color del puntero** que quieras.

---

## 11. Post-reboot — InstallApps (`InstallApps.ps1`)

### Interfaz
- Ventana WPF oscura con categorías, búsqueda por nombre y contador de selección.
- Requiere **winget**.

### Tipos de instalación

| Tipo | Comportamiento |
|------|----------------|
| **winget** | `winget install -e --silent` (o `-s msstore` si aplica) |
| **Descarga directa** | URL + argumentos silenciosos (Cursor, Pretzel, C++ Build Tools, etc.) |
| **mise** | `jdx.mise` vía winget; lenguajes con `mise use --global` |
| **Node.js (mise)** | `node@lts` |
| **Python (mise)** | `python@latest` |
| **Go (mise)** | `go@latest` |

Tras instalar mise o un lenguaje mise:
- Añade binario de mise y `%LOCALAPPDATA%\mise\shims` al PATH de usuario.
- Ejecuta `mise reshim`.

Si seleccionas un lenguaje sin tener mise, se instala `jdx.mise` automáticamente.

### Categorías (no lista exhaustiva de paquetes)
Communication, Browsers, Gaming, Streaming, Design, AI, Utilities, Graphics, Development.

### Al terminar
- Resumen: `Installed X of Y app(s)`.
- Hora de finalización + **Enter para cerrar** la consola.

Tras ejecutarse, borra `InstallApps.ps1`, marcador, hook Run y `Open-InstallApps.ps1`.

**Comprobar:** apps elegidas instaladas; `node -v`, `python --version`, `go version` si seleccionaste mise (Python no debe abrir la Store gracias a Debloat).

---

## Checklist rápido para PC nuevo

Usa esto mañana en orden:

- [ ] Windows actualizado antes o después del OOBE según prefieras
- [ ] `Setup.bat` completado sin errores críticos
- [ ] Tema oscuro, explorador (extensiones, ocultos, Este equipo)
- [ ] Barra de tareas oculta, sin búsqueda, sin widgets
- [ ] Inicio sin recomendaciones; layout vacío
- [ ] Energía: pantalla 3 min, sin suspender
- [ ] Privacidad: ofertas off, ubicación off, portapapeles sin nube
- [ ] `sysdm.cpl`: preset personalizado rendimiento + miniaturas + ClearType (tras cerrar sesión)
- [ ] Sin Copilot, sin OneDrive, sin apps debloatadas
- [ ] `python` no abre Microsoft Store
- [ ] Reinicio → color del puntero
- [ ] Reinicio → InstallApps → software deseado
- [ ] mise / node / python / go si los seleccionaste

---

## Archivos del proyecto

| Archivo | Rol |
|---------|-----|
| `Setup.bat` | Orquestador principal |
| `Configure.ps1` | Apariencia y shell (HKCU) |
| `Privacy.ps1` | Privacidad usuario (HKCU) |
| `Performance.ps1` | Rendimiento visual + gaming (HKCU / HKLM) |
| `Setup-Elevated.ps1` | Pasada admin: Debloat + Performance sistema |
| `Debloat.ps1` | Eliminaciones y políticas sistema |
| `RemoteSupport.ps1` | Quick Assist / RDP opcionales |
| `Install-MousePointerPrompt.ps1` | Registra hook del puntero |
| `Open-MousePointerSettings.ps1` | Runner post-reboot puntero |
| `Install-AppsPrompt.ps1` | Registra hook de InstallApps |
| `Open-InstallApps.ps1` | Runner post-reboot InstallApps |
| `InstallApps.ps1` | Selector e instalador de software (release; puede estar en `.gitignore` local) |
