import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../tema/app_cores.dart';

class RelatorioFaturamentoPage extends StatefulWidget {
  const RelatorioFaturamentoPage({super.key});

  @override
  State<RelatorioFaturamentoPage> createState() =>
      _RelatorioFaturamentoPageState();
}

class _RelatorioFaturamentoPageState extends State<RelatorioFaturamentoPage> {
  DateTime mesSelecionado = DateTime.now();

  String formatarPreco(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  String nomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    if (mes < 1 || mes > 12) return '';
    return meses[mes - 1];
  }

  DateTime get inicioMes {
    return DateTime(mesSelecionado.year, mesSelecionado.month, 1);
  }

  DateTime get fimMes {
    return DateTime(mesSelecionado.year, mesSelecionado.month + 1, 1);
  }

  void mesAnterior() {
    setState(() {
      mesSelecionado = DateTime(
        mesSelecionado.year,
        mesSelecionado.month - 1,
        1,
      );
    });
  }

  void proximoMes() {
    setState(() {
      mesSelecionado = DateTime(
        mesSelecionado.year,
        mesSelecionado.month + 1,
        1,
      );
    });
  }

  Widget cardResumo({
    required String titulo,
    required String valor,
    required IconData icone,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppCores.branco.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppCores.dourado.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icone, color: AppCores.dourado),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  valor,
                  style: const TextStyle(
                  color: AppCores.preto,
                    fontSize: 19,
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

  Widget cardProfissional({
    required String nome,
    required double total,
    required int quantidade,
  }) {
    final ticketMedio = quantidade == 0 ? 0.0 : total / quantidade;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppCores.branco.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppCores.dourado.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AppCores.dourado,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                   color: AppCores.preto,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Faturamento: R\$ ${formatarPreco(total)}',
                  style: const TextStyle(
                    color: AppCores.dourado,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Atendimentos: $quantidade',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ticket médio: R\$ ${formatarPreco(ticketMedio)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Faturamento'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SizedBox.expand(
        child: Container(
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
                  .collection('agendamentos')
                  .where('status', isEqualTo: 'concluido')
                  .where(
                    'dataHora',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes),
                  )
                  .where('dataHora', isLessThan: Timestamp.fromDate(fimMes))
                  .orderBy('dataHora')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Erro ao carregar faturamento',
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

                double totalMes = 0;
                int totalAtendimentos = 0;

                final Map<String, double> totalPorProfissional = {};
                final Map<String, int> qtdPorProfissional = {};

                for (final doc in docs) {
                  final data = doc.data();
                  final dataHora = data['dataHora'];
                  if (dataHora is! Timestamp) continue;

                  totalAtendimentos++;

                  final profissional =
                      data['profissional']?.toString().trim().isNotEmpty == true
                      ? data['profissional'].toString().trim()
                      : 'Sem profissional';

                  final valor = data['preco'] is num
                      ? (data['preco'] as num).toDouble()
                      : 0.0;

                  totalMes += valor;

                  totalPorProfissional[profissional] =
                      (totalPorProfissional[profissional] ?? 0) + valor;

                  qtdPorProfissional[profissional] =
                      (qtdPorProfissional[profissional] ?? 0) + 1;
                }

                final ticketMedio = totalAtendimentos == 0
                    ? 0.0
                    : totalMes / totalAtendimentos;

                final profissionaisOrdenados =
                    totalPorProfissional.keys.toList()..sort((a, b) {
                      return totalPorProfissional[b]!.compareTo(
                        totalPorProfissional[a]!,
                      );
                    });

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppCores.branco.withOpacity(0.08),
                              AppCores.branco.withOpacity(0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                        color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: mesAnterior,
                              icon: const Icon(
                                Icons.chevron_left,
                                color: AppCores.dourado,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${nomeMes(mesSelecionado.month)} ${mesSelecionado.year}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppCores.preto,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: proximoMes,
                              icon: const Icon(
                                Icons.chevron_right,
                                color: AppCores.dourado,
                              ),
                            ),
                          ],
                        ),
                      ),
                      cardResumo(
                        titulo: 'Faturamento do mês',
                        valor: 'R\$ ${formatarPreco(totalMes)}',
                        icone: Icons.attach_money_rounded,
                      ),
                      cardResumo(
                        titulo: 'Atendimentos concluídos',
                        valor: '$totalAtendimentos',
                        icone: Icons.task_alt_rounded,
                      ),
                      cardResumo(
                        titulo: 'Ticket médio',
                        valor: 'R\$ ${formatarPreco(ticketMedio)}',
                        icone: Icons.trending_up_rounded,
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Faturamento por profissional',
                          style: TextStyle(
                           color: AppCores.preto,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (profissionaisOrdenados.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                          color: AppCores.branco,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.06),
                            ),
                          ),
                          child: const Text(
                            'Nenhum atendimento concluído neste mês.',
                            textAlign: TextAlign.center,
                          style: TextStyle(color: AppCores.preto),
                          ),
                        )
                      else
                        ...profissionaisOrdenados.asMap().entries.map((entry) {
                          final index = entry.key;
                          final profissional = entry.value;

                          return Container(
                            key: ValueKey(profissional),
                            child: cardProfissional(
                              nome: '${index + 1}. $profissional',
                              total: totalPorProfissional[profissional] ?? 0,
                              quantidade: qtdPorProfissional[profissional] ?? 0,
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
