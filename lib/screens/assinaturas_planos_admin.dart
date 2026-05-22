import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../tema/app_cores.dart';

class AssinaturasPlanosAdminPage extends StatefulWidget {
  final String? destaqueId;
  final int abaInicial;

  const AssinaturasPlanosAdminPage({
    super.key,
    this.destaqueId,
    this.abaInicial = 0,
  });

  @override
  State<AssinaturasPlanosAdminPage> createState() =>
      _AssinaturasPlanosAdminPageState();
}

class _AssinaturasPlanosAdminPageState extends State<AssinaturasPlanosAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Map<String, GlobalKey> cardKeys = {};

  final tabs = ['Ativas', 'Cancelamento agendado', 'Canceladas'];

  @override
  void initState() {
    _tabController = TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: widget.abaInicial,
    );
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color corStatus(String status) {
    switch (status) {
      case 'ativa':
        return Colors.green;

      case 'cancelamento_agendado':
        return Colors.orange;

      case 'cancelada':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  String formatarData(Timestamp? data) {
    if (data == null) return '-';
    final d = data.toDate().toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String formatarPreco(dynamic valor) {
    if (valor is num) {
      return valor.toDouble().toStringAsFixed(2).replaceAll('.', ',');
    }
    return '0,00';
  }

  bool filtrarPorTab(int index, String status) {
    if (index == 0) {
      return status.toLowerCase() == 'ativa';
    }

    if (index == 1) {
      return status == 'cancelamento_agendado';
    }

    if (index == 2) {
      return status == 'cancelada';
    }

    return false;
  }

  Widget linhaInfo({
    required IconData icon,
    required String texto,
    required Color cor,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: cor,
                fontSize: 13,
                height: 1.3,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget cardAssinatura(String docId, Map<String, dynamic> dados) {
    final nome = dados['cliente']?.toString() ?? '';
    final plano = dados['planoNome']?.toString() ?? '';
    final preco = dados['planoPreco'] ?? 0;
    final status = dados['status']?.toString() ?? '';
    final email = dados['email']?.toString() ?? '';
    final ativadoEm = dados['ativadoEm'] as Timestamp?;
    final reativadoEm = dados['reativadoEm'] as Timestamp?;
    final beneficioTexto = dados['beneficioAteTexto']?.toString() ?? '';

    final expiraEm =
        dados['proximaCobrancaEm'] as Timestamp? ??
        (beneficioTexto.isNotEmpty
            ? Timestamp.fromDate(
                DateTime.tryParse(beneficioTexto) ?? DateTime.now(),
              )
            : null);
    final destaque = widget.destaqueId == docId;

    final cardKey = cardKeys.putIfAbsent(docId, () => GlobalKey());

    if (destaque) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = cardKeys[docId]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            alignment: 0.15,
          );
        }
      });
    }

    return Container(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:Color.fromARGB(255, 247, 223, 166),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: destaque
              ?  Colors.black.withOpacity(0.65)
              : Colors.black.withOpacity(0.06),
          width: destaque ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(234, 219, 195, 1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppCores.dourado,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome.isEmpty ? 'Cliente não informado' : nome,
                      style: const TextStyle(
                        color: AppCores.preto,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.isEmpty ? 'E-mail não informado' : email,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: corStatus(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: corStatus(status).withOpacity(0.3)),
                ),
                child: Text(
                  status == 'ativa'
                      ? 'ATIVA'
                      : status == 'cancelamento_agendado'
                      ? 'AGENDADO'
                      : 'CANCELADA',
                  style: TextStyle(
                    color: corStatus(status),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppCores.preto,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    plano.isEmpty ? 'Plano não informado' : plano,
                    style: const TextStyle(
                      color: AppCores.branco,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  'R\$ ${formatarPreco(preco)}',
                  style: const TextStyle(
                    color: AppCores.dourado,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Container(
            height: 1,
            color: Colors.black.withOpacity(0.06),
          ),

          const SizedBox(height: 4),

          linhaInfo(
            icon: status == 'ativa'
                ? Icons.check_circle_rounded
                : status == 'cancelamento_agendado'
                ? Icons.schedule_rounded
                : Icons.cancel_rounded,
            texto: status == 'ativa'
                ? 'Pagamento aprovado'
                : status == 'cancelamento_agendado'
                ? 'Cancelado, ativo até o vencimento'
                : 'Cancelado',
            cor: status == 'ativa'
                ? Colors.green
                : status == 'cancelamento_agendado'
                ? Colors.orange
                : Colors.redAccent,
            fontWeight: FontWeight.w700,
          ),

          if (status == 'ativa') ...[
            linhaInfo(
              icon: Icons.event_available_rounded,
              texto: 'Ativa em: ${formatarData(ativadoEm)}',
              cor: Colors.grey.shade700,
            ),
            if (reativadoEm != null)
              linhaInfo(
                icon: Icons.restart_alt_rounded,
                texto: 'Reativada em: ${formatarData(reativadoEm)}',
                cor: Colors.grey.shade700,
              ),
            linhaInfo(
              icon: Icons.payments_rounded,
              texto: 'Próxima cobrança: ${formatarData(expiraEm)}',
              cor: Colors.orange.shade700,
              fontWeight: FontWeight.w700,
            ),
          ] else if (status == 'cancelamento_agendado') ...[
            linhaInfo(
              icon: Icons.event_busy_rounded,
              texto:
                  'Cancelamento solicitado em: ${formatarData(dados['canceladoEm'])}',
              cor: Colors.grey.shade700,
            ),
            linhaInfo(
              icon: Icons.access_time_filled_rounded,
              texto: 'Ativo até: ${formatarData(expiraEm)}',
              cor: Colors.orange.shade700,
              fontWeight: FontWeight.w700,
            ),
          ] else if (status == 'cancelada') ...[
            linhaInfo(
              icon: Icons.cancel_schedule_send_rounded,
              texto: 'Cancelado em: ${formatarData(dados['canceladoEm'])}',
              cor: Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Assinaturas',
          style: TextStyle(color: AppCores.preto),
        ),
        iconTheme: const IconThemeData(color: AppCores.preto),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppCores.dourado,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppCores.dourado,
          indicatorWeight: 2.5,
          tabs: tabs.map((t) {
            return Tab(
              child: Text(
                t,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
        ),
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
                .orderBy('criadoEm', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Erro ao carregar',
                    style: TextStyle(color: AppCores.preto),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppCores.dourado),
                );
              }

              final docs = snapshot.data!.docs;

              return TabBarView(
                controller: _tabController,
                children: List.generate(tabs.length, (index) {
                  final filtrados = docs.where((doc) {
                    final status = doc.data()['status']?.toString() ?? '';
                    return filtrarPorTab(index, status);
                  }).toList();

                  if (filtrados.isEmpty) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppCores.branco,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.subscriptions_rounded,
                              size: 42,
                              color: AppCores.dourado.withOpacity(0.9),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhuma assinatura',
                              style: TextStyle(
                                color: AppCores.preto,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'As assinaturas desta aba aparecerão aqui.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: filtrados.length,
                    itemBuilder: (context, i) {
                      return cardAssinatura(
                        filtrados[i].id,
                        filtrados[i].data(),
                      );
                    },
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}
