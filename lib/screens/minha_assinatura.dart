import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'planos.dart';
import '../tema/app_cores.dart';

class MinhaAssinaturaPage extends StatelessWidget {
  const MinhaAssinaturaPage({super.key});

  Color corStatus(String status) {
    switch (status) {
      case 'ativa':
        return Colors.green;
      case 'cancelamento_agendado':
        return Colors.orange;
      case 'cancelada':
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData iconeStatus(String status) {
    switch (status) {
      case 'ativa':
        return Icons.check_circle_rounded;
      case 'cancelamento_agendado':
        return Icons.schedule_rounded;
      case 'cancelada':
      case 'cancelado':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String textoStatus(String status, String pagamentoStatus) {
    if (status == 'ativa') return 'Assinatura ativa';
    if (status == 'cancelamento_agendado') return 'Cancelamento agendado';
    if (status == 'cancelada' || status == 'cancelado') {
      return 'Assinatura cancelada';
    }
    return 'Sem assinatura ativa';
  }

  String textoPagamento(String status, String pagamentoStatus) {
    if (status == 'ativa') return 'Pagamento aprovado';

    if (status == 'cancelamento_agendado') {
      return 'Sua assinatura foi cancelada, mas os benefícios continuam ativos até o vencimento.';
    }

    if (status == 'cancelada' || status == 'cancelado') {
      return 'Assinatura encerrada.';
    }

    return 'Sem assinatura ativa.';
  }

  String formatarPreco(dynamic valor) {
    if (valor is num) {
      return valor.toDouble().toStringAsFixed(2).replaceAll('.', ',');
    }

    if (valor == null) return '0,00';
    final convertido = double.tryParse(valor.toString());
    if (convertido == null) return '0,00';

    return convertido.toStringAsFixed(2).replaceAll('.', ',');
  }

  String formatarData(dynamic data) {
    if (data == null || data is! Timestamp) return '-';

    final d = data.toDate().toLocal();

    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String formatarDataTexto(String data) {
    try {
      final partes = data.split('-');

      if (partes.length != 3) return '--/--/----';

      return '${partes[2]}/${partes[1]}/${partes[0]}';
    } catch (_) {
      return '--/--/----';
    }
  }

  String dataBeneficioAte(Map<String, dynamic> dados) {
    final proximaCobrancaTexto =
        dados['proximaCobrancaTexto']?.toString() ?? '';

    final beneficioAteTexto = dados['beneficioAteTexto']?.toString() ?? '';

    if (proximaCobrancaTexto.isNotEmpty) {
      return formatarDataTexto(proximaCobrancaTexto);
    }

    if (beneficioAteTexto.isNotEmpty) {
      return formatarDataTexto(beneficioAteTexto);
    }

    return formatarData(dados['proximaCobrancaEm']);
  }

  Future<void> cancelarAssinatura(
    BuildContext context,
    String? subscriptionId,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppCores.branco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Cancelar assinatura',
          style: TextStyle(color: AppCores.preto, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Deseja realmente cancelar sua assinatura? Você continuará com acesso aos benefícios até o vencimento.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: AppCores.dourado),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: AppCores.branco,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (subscriptionId == null || subscriptionId.trim().isEmpty) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro: assinatura sem identificação no Asaas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'cancelarAssinatura',
      );

      await callable.call({'subscriptionId': subscriptionId});

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancelamento agendado com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Erro ao cancelar assinatura'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cancelar assinatura: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> reativarAssinatura(
    BuildContext context,
    String? subscriptionId,
  ) async {
    if (subscriptionId == null || subscriptionId.trim().isEmpty) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro: assinatura sem identificação no Asaas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'reativarAssinatura',
      );

      await callable.call({'subscriptionId': subscriptionId});

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assinatura reativada com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Erro ao reativar assinatura'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao reativar assinatura: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? escolherAssinaturaVisivel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final visiveis = docs.where((doc) {
      final status = doc.data()['status']?.toString() ?? '';

      return status == 'ativa' ||
          status == 'cancelamento_agendado' ||
          status == 'cancelada' ||
          status == 'cancelado';
    }).toList();

    if (visiveis.isEmpty) return null;

    QueryDocumentSnapshot<Map<String, dynamic>>? encontrar(String status) {
      for (final doc in visiveis) {
        if ((doc.data()['status']?.toString() ?? '') == status) {
          return doc;
        }
      }
      return null;
    }

    return encontrar('ativa') ??
        encontrar('cancelamento_agendado') ??
        encontrar('cancelada') ??
        encontrar('cancelado') ??
        visiveis.first;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppCores.fundoClaro,
        body: Center(
          child: Text(
            'Usuário não logado',
            style: TextStyle(color: AppCores.preto),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Minha Assinatura'),
        centerTitle: true,
        foregroundColor: AppCores.preto,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppCores.fundoClaro,
              AppCores.fundoClaro2,
              AppCores.branco,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('assinaturas_planos')
                .where('userId', isEqualTo: user.uid)
                .orderBy('criadoEm', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Erro ao carregar assinatura',
                    style: TextStyle(color: AppCores.preto),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppCores.dourado),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final doc = escolherAssinaturaVisivel(docs);

              if (doc == null) {
                return _semAssinatura(context);
              }

              final dados = doc.data();

              final planoNome = dados['planoNome']?.toString() ?? 'Plano';
              final planoDescricao = dados['planoDescricao']?.toString() ?? '';
              final preco = formatarPreco(dados['planoPreco']);
              final status = dados['status']?.toString() ?? '';
              final pagamentoStatus =
                  dados['pagamentoStatus']?.toString() ?? '';
              final subscriptionId = dados['asaasSubscriptionId']?.toString();

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: ListView(
                  children: [
                    _vipCompactCard(
                      planoNome: planoNome,
                      planoDescricao: planoDescricao,
                      preco: preco,
                      status: status,
                      pagamentoStatus: pagamentoStatus,
                    ),
                    const SizedBox(height: 14),
                    _infoCard(
                      titulo: status == 'cancelamento_agendado'
                          ? 'Cancelamento'
                          : 'Pagamento',
                      itens: [
                        _InfoItem(
                          icon: Icons.verified_rounded,
                          label: textoPagamento(status, pagamentoStatus),
                        ),
                        _InfoItem(
                          icon: Icons.access_time_rounded,
                          label:
                              'Solicitada em: ${formatarData(dados['criadoEm'])}',
                        ),
                        if (status == 'ativa' && dados['reativadoEm'] != null)
                          _InfoItem(
                            icon: Icons.restart_alt_rounded,
                            label:
                                'Reativada em: ${formatarData(dados['reativadoEm'])}',
                          ),

                        if (status == 'ativa')
                          _InfoItem(
                            icon: Icons.event_repeat_rounded,
                            label:
                                'Próxima cobrança: ${dataBeneficioAte(dados)}',
                          ),
                        if (status == 'cancelamento_agendado')
                          _InfoItem(
                            icon: Icons.lock_clock_rounded,
                            label:
                                'Benefícios ativos até: ${dataBeneficioAte(dados)}',
                          ),
                        if (status == 'cancelada' || status == 'cancelado')
                          _InfoItem(
                            icon: Icons.event_busy_rounded,
                            label:
                                'Encerrada em: ${formatarData(dados['atualizadoEm'])}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (status == 'ativa')
                      _acaoButton(
                        label: 'Cancelar assinatura',
                        icon: Icons.cancel_outlined,
                        foreground: Colors.redAccent,
                        border: Colors.redAccent.withOpacity(0.25),
                        onPressed: () =>
                            cancelarAssinatura(context, subscriptionId),
                      ),
                    if (status == 'cancelamento_agendado')
                      _acaoButton(
                        label: 'Reativar assinatura',
                        icon: Icons.restart_alt_rounded,
                        foreground: AppCores.dourado,
                        border: AppCores.dourado.withOpacity(0.30),
                        onPressed: () =>
                            reativarAssinatura(context, subscriptionId),
                      ),
                    if (status == 'cancelada' || status == 'cancelado')
                      _acaoButton(
                        label: 'Ver planos',
                        icon: Icons.workspace_premium_rounded,
                        foreground: AppCores.dourado,
                        border: AppCores.dourado.withOpacity(0.30),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PlanosPage(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _vipCompactCard({
    required String planoNome,
    required String planoDescricao,
    required String preco,
    required String status,
    required String pagamentoStatus,
  }) {
    final cor = corStatus(status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppCores.branco,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppCores.dourado.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppCores.dourado,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planoNome,
                      style: const TextStyle(
                        color: AppCores.preto,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (planoDescricao.isNotEmpty)
                      Text(
                        planoDescricao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ $preco',
                style: const TextStyle(
                  color: AppCores.dourado,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '/ Mensal',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconeStatus(status), color: cor, size: 17),
                const SizedBox(width: 7),
                Text(
                  textoStatus(status, pagamentoStatus),
                  style: TextStyle(
                    color: cor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required String titulo, required List<_InfoItem> itens}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppCores.branco,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppCores.preto,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ...itens.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, color: AppCores.dourado, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _acaoButton({
    required String label,
    required IconData icon,
    required Color foreground,
    required Color border,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppCores.branco,
          foregroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: border),
          ),
        ),
      ),
    );
  }

  Widget _semAssinatura(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppCores.branco,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppCores.dourado,
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'Você ainda não possui assinatura ativa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppCores.preto,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Escolha um plano para liberar seus benefícios.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;

  const _InfoItem({required this.icon, required this.label});
}
