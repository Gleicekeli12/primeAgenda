import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'screens/splash.dart';
import 'screens/notificacoes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../tema/app_cores.dart';
import 'package:flutter/foundation.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> configurarPushNotifications() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);

  final token = await messaging.getToken();

  final user = FirebaseAuth.instance.currentUser;

  if (user != null && token != null) {
    await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmAtualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((novoToken) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return;

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .set({
          'fcmToken': novoToken,
          'fcmTokens': FieldValue.arrayUnion([novoToken]),
          'fcmAtualizadoEm': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final admin = message.data['userId'] == 'admin';

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => NotificacoesPage(admin: admin)),
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const PrimeAgendaApp());

  if (kIsWeb) {
    debugPrint('RODANDO WEB');
  }
}

class PrimeAgendaApp extends StatelessWidget {
  const PrimeAgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('configuracoes')
          .doc('app')
          .snapshots(),
      builder: (context, snapshot) {
        final dados = snapshot.data?.data() ?? {};

        final nomeEmpresa =
            dados['nomeEmpresa']?.toString().trim().isNotEmpty == true
            ? dados['nomeEmpresa'].toString()
            : "";

        final subtituloEmpresa =
            dados['subtituloEmpresa']?.toString().trim().isNotEmpty == true
            ? dados['subtituloEmpresa'].toString()
            : "";

        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: subtituloEmpresa.isNotEmpty
              ? "$nomeEmpresa $subtituloEmpresa"
              : nomeEmpresa,

          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: AppCores.dourado,
            scaffoldBackgroundColor: AppCores.fundoClaro,

            colorScheme: const ColorScheme.light(
              primary: AppCores.dourado,
              secondary: AppCores.preto,
              surface: AppCores.branco,
            ),

            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: AppCores.preto,
              centerTitle: true,
              elevation: 0,
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppCores.preto,
                foregroundColor: AppCores.dourado,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          home: const SplashPage(),
        );
      },
    );
  }
}
