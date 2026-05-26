# 📱 Calculadora Shake

Uma calculadora feita em Flutter inspirada na calculadora do iPhone, mas com uma funcionalidade secreta:

Ao chacoalhar o celular, a conta digitada é substituída por uma frase personalizada.

---

# ✨ Demonstração

Exemplo:

```txt
777 + 777

Depois de chacoalhar o celular: MAGICA


🚀 Funcionalidades
✅ Calculadora funcional
✅ Interface inspirada na calculadora do iPhone
✅ Tema escuro
✅ Feedback háptico
✅ Frase secreta configurável
✅ Detecção de movimento (shake)
✅ Salvamento local da frase
✅ APK Android gerado
✅ Suporte preparado para iOS
🛠 Tecnologias utilizadas
Flutter
Dart
sensors_plus
shared_preferences
flutter_launcher_icons
📂 Estrutura do projeto
lib/
 └── main.dart

assets/
 └── icon/
      └── icon.png
⚙️ Como rodar o projeto
Clone o repositório
git clone https://github.com/seu-usuario/calculadora-shake.git

Entre na pasta:

cd calculadora-shake
📦 Instale as dependências
flutter pub get
▶️ Rodar em debug
flutter run
📱 Gerar APK release
flutter build apk --release

APK gerado em:

build/app/outputs/flutter-apk/app-release.apk
🎨 Alterar ícone do aplicativo

Troque a imagem:

assets/icon/icon.png

Depois rode:

dart run flutter_launcher_icons
📝 Configuração do ícone

No pubspec.yaml:

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/icon.png"
  remove_alpha_ios: true
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "assets/icon/icon.png"
📲 Como usar
Digite uma conta
Chacoalhe o celular
A frase secreta aparece na tela

A frase pode ser alterada pelo botão de configurações.

🔒 Observação

Esse projeto foi criado apenas para estudo e diversão.

📸 Interface
Inspirada na calculadora do iPhone
Botões arredondados
Layout minimalista
Dark mode
📌 Dependências principais
dependencies:
  flutter:
    sdk: flutter

  sensors_plus: ^7.0.0
  shared_preferences: ^2.5.0
👨‍💻 Autor

Paulo Henrique

⭐ Projeto

Se curtir o projeto, deixe uma estrela no repositório ⭐