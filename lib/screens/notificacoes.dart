import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'agendamentos_admin.dart';
import 'meus_agendamentos.dart';
import 'assinaturas_planos_admin.dart';
import '../tema/app_cores.dart';

class NotificacoesPage extends StatelessWidget {
  final bool admin;

  const NotificacoesPage({super.key, this.admin = false});

  String formatarDataHora(dynamic valor) {
    if (valor is! Timestamp) return '';

    final d = valor.toDate().toLocal();

    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} às '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final userId = admin ? 'admin' : user?.uid;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: AppCores.fundoClaro,
        body: Center(
          child: Text(
            'Usuário não logado',
            style: TextStyle(color: AppCores.branco),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        backgroundColor: AppCores.fundoClaro,
        centerTitle: true,
      ),
      backgroundColor: AppCores.preto,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notificacoes')
            .where('userId', isEqualTo: userId)
            .orderBy('criadoEm', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Erro ao carregar notificações',
               style: TextStyle(color: AppCores.branco),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppCores.dourado),
            );
          }

          final notificacoes = snapshot.data?.docs ?? [];

          if (notificacoes.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma notificação',
              style: TextStyle(color: AppCores.branco),
              ),
            );
          }

          return ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            itemCount: notificacoes.length,
            itemBuilder: (context, index) {
              final doc = notificacoes[index];
              final dados = doc.data();

              final titulo = dados['titulo']?.toString() ?? 'Notificação';
              final mensagem = dados['mensagem']?.toString() ?? '';
              final lida = dados['lida'] == true;
              final dataHora = formatarDataHora(dados['criadoEm']);

              return Container(
                key: ValueKey(doc.id),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppCores.branco,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: lida
                        ? Colors.black.withOpacity(0.06)
                        : AppCores.dourado.withOpacity(0.55),
                    width: lida ? 1 : 1.4,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    lida
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: AppCores.dourado,
                  ),
                  title: Text(
                    titulo,
                    style: const TextStyle(
                      color: AppCores.preto,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        mensagem,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (dataHora.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dataHora,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  onTap: () async {
                    final destino = dados['destino']?.toString() ?? '';
                    final referenciaId = dados['referenciaId']?.toString();
                    final tipo = dados['tipo']?.toString() ?? '';

                    await FirebaseFirestore.instance
                        .collection('notificacoes')
                        .doc(doc.id)
                        .update({
                          'lida': true,
                          'lidaEm': FieldValue.serverTimestamp(),
                        });

                    if (!context.mounted) return;

                    if (destino == 'agendamentos_admin') {
                      final abaInicial = tipo == 'cliente_cancelou' ? 1 : 0;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AgendamentosAdminPage(
                            destaqueId: referenciaId,
                            abaInicial: abaInicial,
                          ),
                        ),
                      );
                      return;
                    }

                    if (destino == 'agendamentos_cliente') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MeusAgendamentosPage(
                            destaqueId: referenciaId,
                            abaInicial: 1,
                          ),
                        ),
                      );
                      return;
                    }

                    if (destino == 'assinaturas_admin') {
                      final abaInicial = tipo == 'assinatura_ativa'
                          ? 0
                          : tipo == 'cancelamento_agendado'
                          ? 1
                          : 2;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssinaturasPlanosAdminPage(
                            destaqueId: referenciaId,
                            abaInicial: abaInicial,
                          ),
                        ),
                      );
                      return;
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
