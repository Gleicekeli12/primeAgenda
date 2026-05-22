const admin = require("firebase-admin");
//const axios = require("axios");
const { onSchedule } = require("firebase-functions/v2/scheduler");


const {
  onCall,
  //onRequest,
  HttpsError,
} = require("firebase-functions/v2/https");

admin.initializeApp();

/*
const { defineSecret } = require("firebase-functions/params");




const ASAAS_API_KEY = defineSecret("ASAAS_API_KEY");

const ASAAS_BASE_URL = "https://api.asaas.com/v3";


function limparCpf(valor) {
  return String(valor || "").replace(/\D/g, "");
}

function asaasHeaders() {
  return {
    access_token: ASAAS_API_KEY.value(),
    "Content-Type": "application/json",
  };
}

function hojeISO() {
  const hoje = new Date();
  return hoje.toISOString().slice(0, 10);
}

function mapearStatusPagamento(evento, paymentStatus) {
  if (evento === "PAYMENT_CONFIRMED" || evento === "PAYMENT_RECEIVED") {
    return {
      status: "ativa",
      pagamentoStatus: "aprovado",
      planoAtivoNoMomento: true,
    };
  }

  if (
    evento === "PAYMENT_CREDIT_CARD_CAPTURE_REFUSED" ||
    evento === "PAYMENT_REPROVED_BY_RISK_ANALYSIS" ||
    paymentStatus === "REFUSED" ||
    paymentStatus === "REPROVED"
  ) {
    return {
      status: "checkout_criado",
      pagamentoStatus: "pagamento_recusado",
      planoAtivoNoMomento: false,
    };
  }

  if (evento === "PAYMENT_CREATED") {
    return {
      status: "checkout_criado",
      pagamentoStatus: "checkout_criado",
      planoAtivoNoMomento: false,
    };
  }

  if (
    evento === "PAYMENT_PENDING" ||
    evento === "PAYMENT_AWAITING_RISK_ANALYSIS" ||
    paymentStatus === "PENDING"
  ) {
    return {
      status: "checkout_criado",
      pagamentoStatus: "processando",
      planoAtivoNoMomento: false,
    };
  }
  if (paymentStatus === "OVERDUE") {
    return {
      status: "cancelada",
      pagamentoStatus: "vencido",
      planoAtivoNoMomento: false,
    };
  }

  if (
    evento === "PAYMENT_DELETED" ||
    evento === "PAYMENT_REFUNDED" ||
    paymentStatus === "REFUNDED"
  ) {
    return {
      status: "cancelada",
      pagamentoStatus: "cancelado",
      planoAtivoNoMomento: false,
    };
  }

  return {
    status: "checkout_criado",
    pagamentoStatus: "nao_confirmado",
    planoAtivoNoMomento: false,
  };
}

async function atualizarUsuarioAssinatura(userId, status, planoNome) {
  await admin
    .firestore()
    .collection("usuarios")
    .doc(userId)
    .set(
      {
        assinaturaAtiva:
          status === "ativa" || status === "cancelamento_agendado",
        assinaturaStatus: status,
        plano: planoNome || "",
        atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

async function buscarAssinaturaPorUserId(userId) {
  const snapshot = await admin
    .firestore()
    .collection("assinaturas_planos")
    .where("userId", "==", userId)
    .orderBy("criadoEm", "desc")
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  return snapshot.docs[0];
}

async function buscarAssinaturasRecentesDoUsuario(userId) {
  const snapshot = await admin
    .firestore()
    .collection("assinaturas_planos")
    .where("userId", "==", userId)
    .orderBy("criadoEm", "desc")
    .limit(10)
    .get();

  return snapshot.docs;
}

async function buscarAssinaturaPorAsaasSubscriptionId(subscriptionId) {
  const snapshot = await admin
    .firestore()
    .collection("assinaturas_planos")
    .where("asaasSubscriptionId", "==", subscriptionId)
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  return snapshot.docs[0];
}

async function criarClienteAsaas({ nome, email, cpf }) {
  const response = await axios.post(
    `${ASAAS_BASE_URL}/customers`,
    {
      name: nome,
      email,
      cpfCnpj: limparCpf(cpf),
    },
    {
      headers: asaasHeaders(),
    },
  );

  return response.data;
}
async function obterOuCriarClienteAsaas({ userId, nome, email, cpf }) {
  const userRef = admin.firestore().collection("usuarios").doc(userId);
  const userDoc = await userRef.get();

  const asaasCustomerId = userDoc.data()?.asaasCustomerId || "";

  if (asaasCustomerId) {
    return asaasCustomerId;
  }

  const cliente = await criarClienteAsaas({
    nome,
    email,
    cpf,
  });

  await userRef.set(
    {
      asaasCustomerId: cliente.id || "",
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return cliente.id;
}

  exports.criarAssinatura = onCall(
  { secrets: [ASAAS_API_KEY] },
  async (request) => {
    const userId = request.auth?.uid;
    const dados = request.data || {};

    if (!userId) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    const { planoId, planoNome, planoDescricao, valor, email, nome } = dados;

    if (!planoId || !planoNome || !valor || !email || !nome) {
      throw new HttpsError(
        "invalid-argument",
        "Dados incompletos para criar o checkout.",
      );
    }
    console.log("INICIANDO CRIAR ASSINATURA", {
      userId,
      planoId,
      planoNome,
      valor,
      email,
      nome,
    });
    try {
      const assinaturasRecentes =
        await buscarAssinaturasRecentesDoUsuario(userId);

      // Bloqueia se já tiver assinatura ativa ou cancelamento agendado
      const assinaturaAtiva = assinaturasRecentes.find((doc) => {
        const status = doc.data().status;
        return status === "ativa" || status === "cancelamento_agendado";
      });

      if (assinaturaAtiva) {
        throw new HttpsError(
          "failed-precondition",
          "Você já possui uma assinatura ativa.",
        );
      }

      // Reutiliza checkout somente se for do mesmo plano
      const checkoutMesmoPlano = assinaturasRecentes.find((doc) => {
        const dadosAssinatura = doc.data();

        return (
          dadosAssinatura.status === "checkout_criado" &&
          dadosAssinatura.planoId === planoId &&
          dadosAssinatura.asaasPaymentLinkUrl
        );
      });

      if (checkoutMesmoPlano) {
        const assinatura = checkoutMesmoPlano.data();

        return {
          success: true,
          assinaturaDocId: checkoutMesmoPlano.id,
          checkoutUrl: assinatura.asaasPaymentLinkUrl,
          asaasPaymentLinkId: assinatura.asaasPaymentLinkId || "",
          status: assinatura.pagamentoStatus || "checkout_criado",
          message: "Checkout existente reutilizado.",
        };
      }

      // Se tiver checkout antigo de outro plano, marca como expirado
      const checkoutsAntigos = assinaturasRecentes.filter((doc) => {
        const dadosAssinatura = doc.data();

        return (
          dadosAssinatura.status === "checkout_criado" &&
          dadosAssinatura.planoId !== planoId
        );
      });

      for (const checkoutAntigo of checkoutsAntigos) {
        await checkoutAntigo.ref.set(
          {
            status: "checkout_expirado",
            pagamentoStatus: "checkout_expirado",
            planoAtivoNoMomento: false,
            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      const customerId = await obterOuCriarClienteAsaas({
        userId,
        nome,
        email,
        cpf: dados.cpf || "",
      });
      const docRef = await admin
        .firestore()
        .collection("assinaturas_planos")
        .add({
          userId,
          email,
          cliente: nome,
          asaasCustomerId: customerId,

          planoId,
          planoNome,
          planoDescricao: planoDescricao || "",
          planoPreco: Number(valor),
          periodo: "mensal",

          metodoPagamento: "asaas_checkout",
          status: "checkout_criado",
          pagamentoStatus: "checkout_criado",
          planoAtivoNoMomento: false,

          asaasAmbiente: ASAAS_BASE_URL.includes("sandbox")
            ? "sandbox"
            : "producao",

          criadoEm: admin.firestore.FieldValue.serverTimestamp(),
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        });

      const paymentLinkResponse = await axios.post(
        `${ASAAS_BASE_URL}/paymentLinks`,
        {
          name: `Assinatura ${planoNome}`,
          description: planoDescricao || `Assinatura mensal - ${planoNome}`,
          value: Number(valor),
          customer: customerId,
          billingType: "CREDIT_CARD",
          chargeType: "RECURRENT",
          subscriptionCycle: "MONTHLY",
          dueDateLimitDays: 1,
          externalReference: docRef.id,
          notificationEnabled: true,
        },
        {
          headers: asaasHeaders(),
          timeout: 15000,
          validateStatus: () => true,
        },
      );
      console.log(
        "RESPOSTA ASAAS:",
        paymentLinkResponse.status,
        paymentLinkResponse.data,
      );

      const paymentLink = paymentLinkResponse.data;
      console.log("CRIANDO PAYMENT LINK ASAAS");

      await docRef.set(
        {
          asaasPaymentLinkId: paymentLink.id || "",
          asaasPaymentLinkUrl: paymentLink.url || "",
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      console.log("PAYMENT LINK ASAAS OK:", paymentLink.url);

      return {
        success: true,
        assinaturaDocId: docRef.id,
        checkoutUrl: paymentLink.url,
        asaasPaymentLinkId: paymentLink.id,
        status: "checkout_criado",
        message: "Checkout criado com sucesso.",
      };
    } catch (error) {
      console.error(
        "ERRO CRIAR CHECKOUT ASAAS:",
        error.response?.data || error,
      );

      if (error instanceof HttpsError) {
        throw error;
      }
      if (error.code === "ECONNABORTED") {
        throw new HttpsError(
          "deadline-exceeded",
          "O Asaas demorou para responder. Tente novamente em instantes.",
        );
      }

      throw new HttpsError(
        "internal",
        error.response?.data?.errors?.[0]?.description ||
          "Erro ao criar checkout no Asaas.",
      );
    }
  },
);

exports.cancelarAssinatura = onCall(
  { secrets: [ASAAS_API_KEY] },
  async (request) => {
    const userId = request.auth?.uid;
    const { subscriptionId } = request.data || {};

    if (!userId) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    if (!subscriptionId) {
      throw new HttpsError("invalid-argument", "Assinatura inválida.");
    }

    try {
      const doc = await buscarAssinaturaPorAsaasSubscriptionId(subscriptionId);

      if (!doc) {
        throw new HttpsError("not-found", "Assinatura não encontrada.");
      }

      const assinatura = doc.data();

      if (assinatura.userId !== userId) {
        throw new HttpsError(
          "permission-denied",
          "Você não tem permissão para cancelar esta assinatura.",
        );
      }

      if (assinatura.status !== "ativa") {
        throw new HttpsError(
          "failed-precondition",
          "Somente assinaturas ativas podem ser canceladas.",
        );
      }

      const resposta = await axios.put(
        `${ASAAS_BASE_URL}/subscriptions/${subscriptionId}`,
        { status: "INACTIVE" },
        {
          headers: asaasHeaders(),
          timeout: 15000,
          validateStatus: () => true,
        },
      );

      if (resposta.status < 200 || resposta.status >= 300) {
        console.error("ERRO ASAAS INATIVAR:", resposta.status, resposta.data);
        throw new HttpsError(
          "internal",
          resposta.data?.errors?.[0]?.description ||
            "Erro ao agendar cancelamento no Asaas.",
        );
      }

      await doc.ref.set(
        {
          status: "cancelamento_agendado",
          pagamentoStatus: "cancelamento_agendado",
          planoAtivoNoMomento: true,
          renovacaoCancelada: true,
          cancelamentoEfetivadoNoAsaas: true,
          canceladoEm: admin.firestore.FieldValue.serverTimestamp(),
          canceladoPor: "cliente",
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      await atualizarUsuarioAssinatura(
        userId,
        "cancelamento_agendado",
        assinatura.planoNome,
      );

      await admin
        .firestore()
        .collection("notificacoes")
        .add({
          userId: "admin",
          tipo: "cancelamento_agendado",
          destino: "assinaturas_admin",
          referenciaId: doc.id,
          titulo: "Cancelamento agendado",
          mensagem:
            `${assinatura.cliente || "Cliente"} agendou o cancelamento ` +
            `do plano ${assinatura.planoNome || ""}.`,
          lida: false,
          criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        });

      return {
        success: true,
        message: "Cancelamento agendado com sucesso.",
      };
    } catch (error) {
      console.error(
        "ERRO CANCELAR ASSINATURA ASAAS:",
        error.response?.data || error,
      );

      if (error instanceof HttpsError) throw error;

      throw new HttpsError(
        "internal",
        error.response?.data?.errors?.[0]?.description ||
          "Erro ao cancelar assinatura.",
      );
    }
  },
);

exports.reativarAssinatura = onCall(
  { secrets: [ASAAS_API_KEY] },
  async (request) => {
    const userId = request.auth?.uid;
    const { subscriptionId } = request.data || {};

    if (!userId) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    if (!subscriptionId) {
      throw new HttpsError("invalid-argument", "Assinatura inválida.");
    }

    try {
      const doc = await buscarAssinaturaPorAsaasSubscriptionId(subscriptionId);

      if (!doc) {
        throw new HttpsError("not-found", "Assinatura não encontrada.");
      }

      const assinatura = doc.data();

      if (assinatura.userId !== userId) {
        throw new HttpsError(
          "permission-denied",
          "Você não tem permissão para reativar esta assinatura.",
        );
      }

      if (assinatura.status !== "cancelamento_agendado") {
        throw new HttpsError(
          "failed-precondition",
          "Esta assinatura não está com cancelamento agendado.",
        );
      }

      const nextDueDate =
        assinatura.proximaCobrancaTexto || assinatura.beneficioAteTexto;

      if (!nextDueDate) {
        throw new HttpsError(
          "failed-precondition",
          "Data da próxima cobrança não encontrada.",
        );
      }

      const resposta = await axios.put(
        `${ASAAS_BASE_URL}/subscriptions/${subscriptionId}`,
        {
          status: "ACTIVE",
        },
        {
          headers: asaasHeaders(),
          timeout: 15000,
          validateStatus: () => true,
        },
      );

      console.log("RESPOSTA ASAAS REATIVAR:", resposta.status, resposta.data);

      if (resposta.status < 200 || resposta.status >= 300) {
        throw new HttpsError(
          "internal",
          resposta.data?.errors?.[0]?.description ||
            "Erro ao reativar assinatura no Asaas.",
        );
      }

      const statusAsaas = resposta.data?.status || "ACTIVE";

      if (statusAsaas !== "ACTIVE") {
        throw new HttpsError(
          "failed-precondition",
          "O Asaas não confirmou a reativação da assinatura.",
        );
      }

      await doc.ref.set(
        {
          status: "ativa",
          pagamentoStatus: "aprovado",
          planoAtivoNoMomento: true,
          renovacaoCancelada: false,

          cancelamentoEfetivadoNoAsaas: false,
          canceladoEm: null,
          canceladoPor: null,

          asaasStatus: "ACTIVE",
          ultimoEventoAsaas: "SUBSCRIPTION_REACTIVATED",
          reativadoEm: admin.firestore.FieldValue.serverTimestamp(),
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      await atualizarUsuarioAssinatura(userId, "ativa", assinatura.planoNome);

      await admin
        .firestore()
        .collection("notificacoes")
        .add({
          userId: "admin",
          tipo: "assinatura_ativa",
          destino: "assinaturas_admin",
          referenciaId: doc.id,
          titulo: "Assinatura reativada",
          mensagem:
            `${assinatura.cliente || "Cliente"} reativou ` +
            `o plano ${assinatura.planoNome || ""}.`,
          lida: false,
          criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        });

      return {
        success: true,
        message: "Assinatura reativada com sucesso.",
      };
    } catch (error) {
      console.error(
        "ERRO REATIVAR ASSINATURA ASAAS:",
        error.response?.data || error,
      );

      if (error instanceof HttpsError) throw error;

      throw new HttpsError(
        "internal",
        error.response?.data?.errors?.[0]?.description ||
          "Erro ao reativar assinatura.",
      );
    }
  },
);

exports.webhookAsaas = onRequest(
  { secrets: [ASAAS_API_KEY] },
  async (req, res) => {
    try {
      const body = req.body || {};
      const evento = body.event || "";

      console.log("WEBHOOK ASAAS RECEBIDO:", JSON.stringify(body));

      const payment = body.payment || null;
      const subscription = body.subscription || null;

      if (payment) {
        let doc = null;
        let docRef = null;

        // 1) Tenta achar pelo externalReference
        if (payment.externalReference) {
          docRef = admin
            .firestore()
            .collection("assinaturas_planos")
            .doc(payment.externalReference);

          const docSnap = await docRef.get();

          if (docSnap.exists) {
            doc = docSnap;
          }
        }

        // 2) Se não achou, tenta achar pelo subscriptionId
        if (!doc && payment.subscription) {
          const snapshot = await admin
            .firestore()
            .collection("assinaturas_planos")
            .where("asaasSubscriptionId", "==", payment.subscription)
            .limit(1)
            .get();

          if (!snapshot.empty) {
            doc = snapshot.docs[0];
            docRef = doc.ref;
          }
        }

        // 3) Se ainda não achou, ignora sem quebrar webhook
        if (!doc || !docRef) {
          console.log(
            "Documento não encontrado:",
            payment.externalReference || payment.subscription || "",
          );
          return res.status(200).send("ok");
        }

        const assinatura = doc.data();

        // NÃO deixa assinatura ativa voltar para checkout_criado
        if (
          (assinatura.status === "ativa" ||
            assinatura.status === "cancelamento_agendado") &&
          (evento === "PAYMENT_CREATED" ||
            evento === "PAYMENT_PENDING" ||
            evento === "PAYMENT_AWAITING_RISK_ANALYSIS")
        ) {
          await docRef.set(
            {
              ultimoEventoAsaas: evento,
              asaasPaymentId: payment?.id || "",
              asaasPaymentStatus: payment?.status || "",
              atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );

          return res.status(200).send("ok");
        }

        const statusMapeado = mapearStatusPagamento(evento, payment.status);

        const dadosAtualizacao = {
          ...statusMapeado,
          ultimoEventoAsaas: evento,
          asaasPaymentId: payment.id || "",
          asaasPaymentStatus: payment.status || "",
          asaasInvoiceUrl: payment.invoiceUrl || "",
          asaasBankSlipUrl: payment.bankSlipUrl || "",
          asaasTransactionReceiptUrl: payment.transactionReceiptUrl || "",

          asaasSubscriptionId:
            payment.subscription || assinatura.asaasSubscriptionId || "",

          vencimentoAtual: payment.dueDate || "",
          valorAtual: payment.value || null,

          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (statusMapeado.status === "ativa") {
          dadosAtualizacao.ativadoEm =
            admin.firestore.FieldValue.serverTimestamp();

          dadosAtualizacao.asaasStatus = "ACTIVE";

          let proximaCobrancaTexto = "";

          if (assinatura.proximaCobrancaTexto) {
            proximaCobrancaTexto = assinatura.proximaCobrancaTexto;
          }

          if (!proximaCobrancaTexto && payment.dueDate) {
            const partes = payment.dueDate.split("-");
            const ano = Number(partes[0]);
            const mes = Number(partes[1]);
            const dia = Number(partes[2]);

            const proxima = new Date(ano, mes - 1, dia);

            // adiciona 1 mês
            proxima.setMonth(proxima.getMonth() + 1);

            const proximoAno = proxima.getFullYear();
            const proximoMes = String(proxima.getMonth() + 1).padStart(2, "0");
            const proximoDia = String(proxima.getDate()).padStart(2, "0");

            proximaCobrancaTexto = `${proximoAno}-${proximoMes}-${proximoDia}`;
          }

          dadosAtualizacao.proximaCobrancaTexto = proximaCobrancaTexto;
          dadosAtualizacao.beneficioAteTexto = proximaCobrancaTexto;
          dadosAtualizacao.vencimentoAtual = proximaCobrancaTexto;

          dadosAtualizacao.proximaCobrancaEm = proximaCobrancaTexto
            ? admin.firestore.Timestamp.fromDate(
                new Date(`${proximaCobrancaTexto}T00:00:00-03:00`),
              )
            : null;
        }

        await docRef.set(dadosAtualizacao, { merge: true });

        await atualizarUsuarioAssinatura(
          assinatura.userId,
          statusMapeado.status,
          assinatura.planoNome,
        );

        // 🔥 ADMIN - ASSINATURA ATIVA
        if (statusMapeado.status === "ativa") {
          await admin
            .firestore()
            .collection("notificacoes")
            .add({
              userId: "admin",

              tipo: "assinatura_ativa",
              destino: "assinaturas_admin",
              referenciaId: docRef.id,

              titulo: "Nova assinatura ativa",

              mensagem:
                `${assinatura.cliente || "Cliente"} ativou ` +
                `o plano ${assinatura.planoNome || ""}.`,

              lida: false,
              criadoEm: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        // 🔥 ADMIN - CANCELAMENTO AGENDADO
        if (statusMapeado.status === "cancelamento_agendado") {
          await admin
            .firestore()
            .collection("notificacoes")
            .add({
              userId: "admin",

              tipo: "cancelamento_agendado",
              destino: "assinaturas_admin",
              referenciaId: docRef.id,

              titulo: "Cancelamento agendado",

              mensagem:
                `${assinatura.cliente || "Cliente"} ` +
                `agendou cancelamento da assinatura.`,

              lida: false,
              criadoEm: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        // 🔥 ADMIN - ASSINATURA CANCELADA
        if (statusMapeado.status === "cancelada") {
          await admin
            .firestore()
            .collection("notificacoes")
            .add({
              userId: "admin",

              tipo: "assinatura_cancelada",
              destino: "assinaturas_admin",
              referenciaId: docRef.id,

              titulo: "Assinatura cancelada",

              mensagem:
                `${assinatura.cliente || "Cliente"} ` +
                `teve a assinatura cancelada.`,

              lida: false,
              criadoEm: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        return res.status(200).send("ok");
      }

      if (subscription && subscription.id) {
        let doc = await buscarAssinaturaPorAsaasSubscriptionId(subscription.id);

        // Se ainda não salvou pelo subscriptionId, tenta pelo externalReference
        if (!doc && subscription.externalReference) {
          const docRef = admin
            .firestore()
            .collection("assinaturas_planos")
            .doc(subscription.externalReference);

          const docSnap = await docRef.get();

          if (docSnap.exists) {
            doc = docSnap;
          }
        }

        if (!doc) {
          console.log(
            "Subscription webhook sem doc local:",
            subscription.id,
            subscription.externalReference || "",
          );
          return res.status(200).send("ok");
        }

        const assinatura = doc.data();
        const docRef = doc.ref;

        if (
          assinatura.status === "cancelamento_agendado" &&
          (evento === "PAYMENT_CREATED" ||
            evento === "PAYMENT_PENDING" ||
            evento === "PAYMENT_AWAITING_RISK_ANALYSIS")
        ) {
          await docRef.set(
            {
              ultimoEventoAsaas: evento,
              asaasPaymentId: payment?.id || "",
              asaasPaymentStatus: payment?.status || "",
              atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );

          return res.status(200).send("ok");
        }

        if (
          evento === "SUBSCRIPTION_DELETED" ||
          evento === "SUBSCRIPTION_INACTIVATED"
        ) {
          await doc.ref.set(
            {
              status: "cancelamento_agendado",
              pagamentoStatus: "cancelamento_agendado",
              planoAtivoNoMomento: true,
              renovacaoCancelada: true,
              ultimoEventoAsaas: evento,
              asaasStatus: subscription.status || "DELETED",
              atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
          await atualizarUsuarioAssinatura(
            assinatura.userId,
            "cancelamento_agendado",
            assinatura.planoNome,
          );
        } else {
          await doc.ref.set(
            {
              ultimoEventoAsaas: evento,
              asaasStatus: subscription.status || "",
              asaasSubscriptionId: subscription.id || "",
              asaasSubscriptionCycle: subscription.cycle || "",
              asaasBillingType: subscription.billingType || "",
              proximaCobrancaTexto:
                subscription.nextDueDate ||
                assinatura.proximaCobrancaTexto ||
                "",
              beneficioAteTexto:
                subscription.nextDueDate || assinatura.beneficioAteTexto || "",
              atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        return res.status(200).send("ok");
      }

      return res.status(200).send("ok");
    } catch (error) {
      console.error("ERRO WEBHOOK ASAAS:", error);
      return res.status(200).send("ok");
    }
  },
);

exports.finalizarAssinaturasVencidas = onSchedule(
  {
    schedule: "every day 03:00",
    timeZone: "America/Sao_Paulo",
  },
  async () => {
    const hoje = hojeISO();

    const snapshot = await admin
      .firestore()
      .collection("assinaturas_planos")
      .where("status", "==", "cancelamento_agendado")
      .where("beneficioAteTexto", "<=", hoje)
      .get();

    const batch = admin.firestore().batch();

    for (const doc of snapshot.docs) {
      const assinatura = doc.data();

      batch.set(
        doc.ref,
        {
          status: "cancelada",
          asaasStatus: "EXPIRED",
          pagamentoStatus: "cancelado",
          planoAtivoNoMomento: false,
          renovacaoCancelada: true,
          encerradoEm: admin.firestore.FieldValue.serverTimestamp(),
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      if (assinatura.userId) {
        const userRef = admin
          .firestore()
          .collection("usuarios")
          .doc(assinatura.userId);

        batch.set(
          userRef,
          {
            assinaturaAtiva: false,
            assinaturaStatus: "cancelada",
            plano: "",
            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }

    await batch.commit();

    console.log(`Assinaturas vencidas finalizadas: ${snapshot.size}`);
  },
);

*/

const { onDocumentCreated } = require("firebase-functions/v2/firestore");

exports.enviarPushNotificacao = onDocumentCreated(
  "notificacoes/{notificacaoId}",
  async (event) => {
    try {
      const dados = event.data.data();
      const userId = dados.userId;

      if (!userId) return;

      let tokens = [];

      // 🔥 CASO ADMIN
      if (userId === "admin") {
        const admins = await admin
          .firestore()
          .collection("usuarios")
          .where("tipo", "==", "admin")
          .get();

        admins.forEach((doc) => {
          const t = doc.data().fcmTokens || [];
          tokens.push(...t);
        });
      } else {
        // 🔥 CASO CLIENTE
        const userDoc = await admin
          .firestore()
          .collection("usuarios")
          .doc(userId)
          .get();

        if (!userDoc.exists) return;

        tokens = userDoc.data()?.fcmTokens || [];
      }

      tokens = [...new Set(tokens)].filter(Boolean);

      if (!tokens.length) {
        console.log("Nenhum token encontrado");
        return;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: {
          title: dados.titulo || "Notificação",
          body: dados.mensagem || "",
        },
        data: {
          tela: "notificacoes",
          userId: String(userId),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "default",
            sound: "default",
          },
        },
      });

      console.log(
        "Push enviado:",
        response.successCount,
        "falhas:",
        response.failureCount,
      );
    } catch (error) {
      console.error("Erro ao enviar push:", error);
    }
  },
);
exports.criarAgendamento = onCall(async (request) => {
  const userId = request.auth?.uid;
  const dados = request.data || {};

  if (!userId) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  const { servico, servicoId, profissional, profissionalId, data, horario, preco } =
    dados;

  const precoServico = Number(preco || 0);

  if (!Number.isFinite(precoServico) || precoServico <= 0) {
    throw new HttpsError("invalid-argument", "Preço do serviço inválido.");
  }

  if (!servico || !servicoId || !profissional || !profissionalId || !data || !horario) {
    throw new HttpsError("invalid-argument", "Dados incompletos.");
  }

  try {
    const db = admin.firestore();

    const dataBase = new Date(data);

    const ano = dataBase.getFullYear();
    const mes = String(dataBase.getMonth() + 1).padStart(2, "0");
    const dia = String(dataBase.getDate()).padStart(2, "0");

    const dataDia = `${ano}-${mes}-${dia}`;

    // força horário Brasil UTC-3
    const dataHora = new Date(`${ano}-${mes}-${dia}T${horario}:00-03:00`);

    if (dataHora.getTime() <= Date.now()) {
      throw new HttpsError(
        "failed-precondition",
        "Não é possível agendar em data ou horário passado.",
      );
    }

    const horarioId = horario.replace(":", "h");
    const bloqueioId = `${profissionalId}_${dataDia}_${horarioId}`;

    const bloqueioRef = db.collection("bloqueios_agendamentos").doc(bloqueioId);
    const agendamentoRef = db.collection("agendamentos").doc();

    const conflitoCliente = await db
      .collection("agendamentos")
      .where("userId", "==", userId)
      .where("dataDia", "==", dataDia)
      .where("hora", "==", horario)
      .where("status", "==", "agendado")
      .limit(1)
      .get();

    if (!conflitoCliente.empty) {
      throw new HttpsError(
        "failed-precondition",
        "Você já tem um agendamento neste dia e horário. Escolha outro horário.",
      );
    }

    const conflitoProfissionalDia = await db
      .collection("agendamentos")
      .where("userId", "==", userId)
      .where("profissionalId", "==", profissionalId)
      .where("dataDia", "==", dataDia)
      .where("status", "==", "agendado")
      .limit(1)
      .get();

    if (!conflitoProfissionalDia.empty) {
      throw new HttpsError(
        "failed-precondition",
        "Você já tem um agendamento com esse profissional nesse dia. Escolha outro profissional.",
      );
    }

    const userDoc = await db.collection("usuarios").doc(userId).get();
    const nomeCliente = userDoc.data()?.nome?.trim() || "Cliente";

    await db.runTransaction(async (transaction) => {
      const bloqueioSnap = await transaction.get(bloqueioRef);

      if (bloqueioSnap.exists) {
        throw new HttpsError(
          "already-exists",
          "Esse horário acabou de ser ocupado. Escolha outro horário.",
        );
      }

      transaction.set(bloqueioRef, {
        agendamentoId: agendamentoRef.id,
        profissionalId,
        dataDia,
        hora: horario,
        userId,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(agendamentoRef, {
        cliente: nomeCliente,
        userId,
        servico,
        servicoId,
        preco: precoServico,
        profissional,
        profissionalId,
        data: admin.firestore.Timestamp.fromDate(dataHora),
        dataHora: admin.firestore.Timestamp.fromDate(dataHora),
        dataDia,
        hora: horario,
        status: "agendado",
        bloqueioId,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    const dataFormatada = dataDia.split("-").reverse().join("/");

    await db.collection("notificacoes").add({
      userId: "admin",
      tipo: "novo_agendamento",
      destino: "agendamentos_admin",
      referenciaId: agendamentoRef.id,
      titulo: "Novo agendamento",
      mensagem:
        `${nomeCliente} agendou com ${profissional} ` +
        `no dia ${dataFormatada} às ${horario}.`,
      dataAgendamento: dataDia,
      horaAgendamento: horario,
      lida: false,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, message: "Agendamento feito com sucesso" };
  } catch (error) {
    console.error("ERRO CRIAR AGENDAMENTO:", error);

    if (error instanceof HttpsError) throw error;

    throw new HttpsError("internal", "Erro ao criar agendamento.");
  }
});
async function verificarAdmin(userId) {
  const doc = await admin.firestore().collection("usuarios").doc(userId).get();

  if (!doc.exists || doc.data()?.tipo !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Apenas o administrador pode fazer essa ação.",
    );
  }

  return doc.data()?.nome || "Admin";
}

exports.atualizarStatusAgendamentoAdmin = onCall(async (request) => {
  const userId = request.auth?.uid;
  const { agendamentoId, acao } = request.data || {};

  if (!userId) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  if (!agendamentoId || !acao) {
    throw new HttpsError("invalid-argument", "Dados incompletos.");
  }

  if (!["cancelado", "concluido", "nao_compareceu"].includes(acao)) {
    throw new HttpsError("invalid-argument", "Ação inválida.");
  }

  const nomeAdmin = await verificarAdmin(userId);
  const db = admin.firestore();

  const ref = db.collection("agendamentos").doc(agendamentoId);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "Agendamento não encontrado.");
  }

  const dados = snap.data();

  if (dados.status !== "agendado") {
    throw new HttpsError(
      "failed-precondition",
      "Esse agendamento não está mais agendado.",
    );
  }

  const update = {
    status: acao,
    marcadoPor: nomeAdmin,
    acaoAdmin: acao,
    acaoAdminPor: nomeAdmin,
    acaoAdminEm: admin.firestore.FieldValue.serverTimestamp(),
    atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (acao === "cancelado") {
    update.canceladoPor = "admin";
    update.canceladoPorNome = nomeAdmin;
    update.canceladoEm = admin.firestore.FieldValue.serverTimestamp();
  }

  if (acao === "concluido") {
    update.concluidoEm = admin.firestore.FieldValue.serverTimestamp();
  }

  if (acao === "nao_compareceu") {
    update.naoCompareceuEm = admin.firestore.FieldValue.serverTimestamp();
  }
  if (acao === "concluido" || acao === "nao_compareceu") {
    const dataHora = dados.dataHora?.toDate ? dados.dataHora.toDate() : null;

    if (!dataHora) {
      throw new HttpsError(
        "failed-precondition",
        "Data do agendamento inválida.",
      );
    }

    const liberarEm = new Date(dataHora.getTime() + 15 * 60 * 1000);

    if (new Date() < liberarEm) {
      throw new HttpsError(
        "failed-precondition",
        "Essa ação só pode ser feita 15 minutos após o horário agendado.",
      );
    }
  }
  await ref.update(update);
  if (acao === "cancelado" && dados.bloqueioId) {
    await db
      .collection("bloqueios_agendamentos")
      .doc(dados.bloqueioId)
      .delete();
  }
  if (acao === "cancelado" && dados.userId) {
    const dataCancelamento = (dados.dataDia || "")
      .split("-")
      .reverse()
      .join("/");

    await db.collection("notificacoes").add({
      userId: dados.userId,
      tipo: "admin_cancelou",
      destino: "agendamentos_cliente",
      referenciaId: agendamentoId,
      titulo: "Agendamento cancelado",

      mensagem:
        `Seu agendamento com ${dados.profissional || ""} ` +
        `no dia ${dataCancelamento} às ${dados.hora || ""} ` +
        `foi cancelado pelo estabelecimento.`,

      dataAgendamento: dados.dataDia || "",
      horaAgendamento: dados.hora || "",
      lida: false,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  return {
    success: true,
    message: "Agendamento atualizado com sucesso.",
  };
});

exports.atualizarTempoServidor = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "America/Sao_Paulo",
  },
  async () => {
    await admin.firestore().collection("controle_tempo").doc("agora").set(
      {
        dataHora: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  },
);
