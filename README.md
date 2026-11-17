# Larc en Pet 🌈

Memorial 3D para mascotas en el navegador. Los visitantes entran a un hall compartido, crean su personaje y recorren galerías donde cuelgan la foto de su mascota. Ahí pueden encender velitas, dejar flores y regalos, soltar faroles y firmar el libro de visitas.

![Hall de entrada](captura-hall.png)

## Funciones

- **Hall de entrada compartido:** fuente con la vela de la comunidad, tablón de recuerdos, recién llegados y arcos que llevan a cada galería.
- **Galerías por pisos:** 10 lugares por piso, con una escalera al cielo. Cuando un piso se llena, se abre el siguiente.
- **Memorial de cada mascota:** foto, nombre, fechas, epitafio, velitas (duran 30 días), flores, regalos, faroles y libro de visitas.
- **Angelitos 2D:** cada mascota tiene un angelito ilustrado según su especie, con alas animadas y el color tomado de su foto.
- **Editor de personaje:** opciones distintas para mujer y hombre (cuerpo, peinados, ropa, calzado, accesorios), con tono de piel y colores.
- **Visitantes en vivo:** se ven los demás visitantes con su nombre, y se pueden enviar saludos con emojis y burbujas de diálogo.
- **Chat** en el hall y en cada memorial, con moderación.
- **Tutorial de bienvenida** paso a paso.
- Se controla con toque, joystick, teclado (WASD o flechas) y arrastrando para girar la cámara.

![Personajes](captura-personajes.png)
![Angelitos](captura-angelitos.png)

## Cómo funciona por dentro

- Es un solo archivo `index.html`, sin dependencias ni paso de compilación. Incluye un motor WebGL propio (unas 1.500 líneas).
- Todas las texturas (madera, mármol, papel mural, letreros, angelitos) se generan con canvas al cargar la página. No usa imágenes externas.
- Los datos pasan por una capa de *backend* intercambiable:
  - **Dentro de Claude (artifact):** usa las capacidades `db` (datos compartidos) y `room` (presencia en vivo).
  - **Con Supabase configurado:** base de datos, fotos, inicio de sesión, tiempo real y presencia compartidos. Ver la sección "Conectar Supabase".
  - **Sin configuración:** funciona en **modo local**, donde todo se guarda en el `localStorage` de cada visitante.

## Probar localmente

Abre `index.html` en el navegador, o sírvelo con:

```bash
python3 -m http.server 8000
# luego abre http://localhost:8000
```

## Publicar en GitHub Pages

1. Crea un repositorio (`larc-en-pet`) y sube estos archivos.
2. Ve a **Settings → Pages → Build and deployment**, elige **Deploy from a branch**, la rama `main` y la carpeta `/ (root)`.
3. En uno o dos minutos queda disponible en `https://jeanmunoz402-jpg.github.io/larc-en-pet/`.

## Conectar Supabase (versión pública compartida)

Con Supabase, todos los visitantes del sitio público ven lo mismo: mascotas, velitas, flores, libro de visitas, chat y visitantes en vivo.

1. **Base de datos:** en Supabase ve a **SQL Editor → New query**, pega todo [`supabase/schema.sql`](supabase/schema.sql) y toca **Run**. Esto crea:
   - Las tablas.
   - Las reglas de seguridad (RLS).
   - El tiempo real.
   - El bucket de fotos.
   - El anti-spam y el ocultamiento automático de mensajes reportados.
2. **Claves:** en **Project Settings → API**, copia la *Project URL* y la *anon public key*, y pégalas al inicio de `index.html`:
   ```js
   window.LARC_CONFIG = window.LARC_CONFIG || {supabaseUrl: 'https://xxxx.supabase.co', supabaseKey: 'eyJ...'};
   ```
   La *anon key* es pública por diseño. **Nunca** pongas la `service_role` key.
3. **Inicio de sesión (solo con correo):** en **Authentication → URL Configuration**, pon como *Site URL* `https://jeanmunoz402-jpg.github.io/larc-en-pet/` y agrégala también en *Redirect URLs*.
   - Recomendado: en **Authentication → Emails → Magic Link**, agrega `{{ .Token }}` al cuerpo del correo. Así el correo también trae un código de 6 dígitos que se puede escribir en la pantalla de bienvenida. Es útil cuando el enlace se abre en otro navegador del celular.
4. **Administrador:** inicia sesión una vez en la app. Luego, en el SQL Editor, ejecuta lo siguiente con tu id (lo encuentras en **Authentication → Users**):
   ```sql
   insert into public.admins (user_id) values ('TU-ID');
   ```
   Como administrador puedes borrar cualquier mensaje.

### Qué se comparte en vivo

- **Presencia:** se ve a los demás caminando con su personaje y su nombre, y quién está visitando cada mascota ("👥 2 aquí").
- **Burbujas:** lo que escribes en el chat aparece sobre tu personaje durante 7 segundos.
- **Chat:** hay un chat en el hall y otro en cada memorial, con historial.
- **Avisos:** aparece una notificación cuando alguien enciende una velita o deja una flor.
- **Moderación:**
  - Filtro de groserías y enlaces.
  - Máximo 5 mensajes cada 30 segundos.
  - Botones para reportar ⚑ y silenciar 🔇. Con 3 reportes el mensaje se oculta solo.
  - El autor o un administrador pueden borrar mensajes.
- **Permisos:**
  - Encender velitas, dejar flores y regalos: libre.
  - Firmar el libro de visitas, conversar y añadir mascotas: requiere iniciar sesión.

## Próximos pasos

- Panel de moderación (revisar reportes).
- Editar o retirar un memorial propio.
- Términos de uso y política de privacidad.
- Monetización: plan "Luz eterna", recuerdos físicos con QR y alianzas con veterinarias.

## Licencia

Por definir. Si quieres conservar los derechos para un producto comercial, publica el repositorio como **privado**, o como público con licencia "todos los derechos reservados".
