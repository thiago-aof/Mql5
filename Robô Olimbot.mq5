//+------------------------------------------------------------------+
//|                                                 Robô Olimbot.mq5 |
//|                                                  Thiago Oliveira |
//|                                           https://olimbot.com.br |
//+------------------------------------------------------------------+
#property copyright "Thiago Oliveira"         // Nome do autor
#property link      "https://olimbot.com.br"  // Link de alguma página para autor
#property version   "1.01"                    // Versão

#include <Trade\Trade.mqh> // Biblioteca nativa da plataforma
CTrade trade; // inicialização da chamada da classe

enum e_sn // Nosso enumerador personalizado
  {
   nao = 0,     // Não
   sim = 1      // Sim
  };

enum e_filling // Enumerador personalizado para corrigir alguns nativos
  {
   fok = ORDER_FILLING_FOK,      // Prenchimento Fok
   ioc = ORDER_FILLING_IOC,      // Prenchimento IOC
   ret = ORDER_FILLING_RETURN    // Prenchimento Return
  };

sinput group  "Variáveis Iniciais"
sinput ulong  in_magic  = 1234;                    // Meu ID
sinput e_filling in_filling = ret;                // Tipo de Preenchimento
input double in_volume = 1;                       // Volume

sinput group  "Critérios de Saída"
input double in_sl     = 0;                       // Stoploss
input double in_tp     = 0;                       // TakeProfit
input e_sn   in_usar_saida = sim;                 // Usar sinal na saída

sinput group  "Indicador Bandas de Bolinger"
input int    in_ma_periodo = 21;                  // Periodo BB
input int    in_shift = 0;                        // Deslocamente BB
input double in_desvios = 2;                      // Desvio BB
input ENUM_APPLIED_PRICE in_tipo = PRICE_CLOSE;   // Tipo de aplicação BB

sinput group  "Indicador Bandas de Envelopes"
input int    in_env_periodo = 21;                    // Periodo Envelopes
input int    in_env_shift = 0;                       // Deslocamente Envelopes
input double  in_env_desvios = 0.2;                   // Desvios Envelopes
input ENUM_MA_METHOD     in_env_metodo = MODE_EMA;    // Tipo de média
input ENUM_APPLIED_PRICE in_env_tipo = PRICE_CLOSE;   // Tipo de aplicação Envelopes

sinput group  "Gerenciamento de horários"
input e_sn   in_usar_horario = sim;                 // Usar horário
input string in_inicio = "09:00";                 // Horário de inicio
input string in_parar  = "17:00";                 // Horário final
input e_sn   in_usar_zerar = sim;                 // Usar Zeragem compulsária
input string in_zerar  = "17:30";                 // Horário zeragem

struct s_posicao // nossa estrutura personalizada
  {
   double            volume; // Lot
   double            price; // Preço da posição
   ulong             ticket; // bIlhete da posição
   double            sl;     // Stop Loss
   double            tp;     // Take Profit
   datetime          hora; // Hora de abertura
  };

MqlDateTime time_inicio, time_parar, time_zerar, time_corrente; // Estruturas de horários padrões
int handle, handle2; // Manipuladores dos indicadores, variáveis
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() // Função nativa ao ligar o expert
  {
   EventSetTimer(1);
   trade.SetExpertMagicNumber(in_magic); // Definimos ID
   trade.SetTypeFilling((ENUM_ORDER_TYPE_FILLING)in_filling); // Definimos preenchimento

   handle = iBands(_Symbol,PERIOD_CURRENT,in_ma_periodo,in_shift,in_desvios,in_tipo); // Inicia o indicador BB
   handle2 = iEnvelopes(_Symbol,PERIOD_CURRENT,in_env_periodo,in_env_shift,in_env_metodo,in_env_tipo,in_env_desvios); // Inicia Envelopes

   if(handle == INVALID_HANDLE) // Verificação do manipulador
     {
      printf("ERRO no manipulador do indicador bandas de bolinger");
      return INIT_FAILED; // Nega a inicialização do expert
     }

   if(handle2 == INVALID_HANDLE) // Checa se carregou o indicador corretamente
     {
      printf("ERRO no manipulador do indicador envelopes");
      return INIT_FAILED;
     }

   ChartIndicatorAdd(0,0,handle); // INSERE O INDICADOR NO GRÁFICO
   ChartIndicatorAdd(0,0,handle2);

   TimeToStruct(StringToTime(in_inicio),time_inicio); // Tranformando em estrura nosso valor de horário
   TimeToStruct(StringToTime(in_parar),time_parar);
   TimeToStruct(StringToTime(in_zerar),time_zerar);
   return(INIT_SUCCEEDED); // Confirmação da inicialização
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) // Função ao desligar o expert
  {
   deletar(); // Chamada da função que remove os indicadores
   IndicatorRelease(handle); // Libera a memória
   IndicatorRelease(handle2);

   EventKillTimer(); // Finaliza o evento timer
   Sleep(5000); // Pausa para evitar remoção dos nosso indicadores
  }
//+------------------------------------------------------------------+
//| Deletar Indicadores                                              |
//+------------------------------------------------------------------+
void deletar()
  {
   for(int i=ChartIndicatorsTotal(0,0)-1; i>=0; i--) // Loope que percorre todos os indicadors
     {
      string short_name = ChartIndicatorName(0,0,i); // Função que pega o nome dos indicadores
      ChartIndicatorDelete(0,0,short_name); // Remove os indicadores
     }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() // Função nativa que processa a cada tick
  {
   if(!checar_permissao()) // Checa Permissão
      return;

   s_posicao pos = posicao(); // Checa a posição

   if(horario_zeragem()) // Checa o horário de zeragem
      zeragem(); // zera
   else
      if(pos.volume == 0.0) // Se não tiver posição
        {
         if(horario_operacional()) // Verifica Horário operacional
            if(sinal_entrada()) // Procura sinal de entradsa
               printf("Sinal de entrada gerado!");
        }
      else
        {
         if(in_usar_saida == true)
            if(sinal_saida(pos.volume,pos.ticket)) // Procura sinal de saída
               printf("Sinal de saída gerado!");
        }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   TimeToStruct(TimeCurrent(),time_corrente); // Atualiza horário a cada segundo
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {

  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {

  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---

  }
//+------------------------------------------------------------------+
//| Função Posição                                                   |
//+------------------------------------------------------------------+
s_posicao posicao(void)
  {
   s_posicao posicionamento; // Iniciando estrutura que receberá os dados da posição
   ZeroMemory(posicionamento); // Coloca todas as variaveis como zero

// Loop para percorrer todas as posições
   for(int i=PositionsTotal()-1; i>=0; i--) 
     {
      ulong ticket = PositionGetTicket(i); // Selecionando o bilhete da posição
      PositionSelectByTicket(ticket);

      string ativo = PositionGetString(POSITION_SYMBOL); // Pegando ativo da posição
      ulong magic = PositionGetInteger(POSITION_MAGIC); // Id do expert

      if(ativo != _Symbol) // Checa se o ativo da posição é o mesmo da janela corrente
         continue;

      if(magic != in_magic)// Checa se o id da posição é o mesmo do expert
         continue;

      ENUM_POSITION_TYPE tipo = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); // Tipo de posição
      double vol = PositionGetDouble(POSITION_VOLUME); // Volume da posição
      datetime hora = (datetime)PositionGetInteger(POSITION_TIME); // Hora de abertura da posição

      if(tipo == POSITION_TYPE_BUY) // Verifica se é compra
         posicionamento.volume += vol;

      if(tipo == POSITION_TYPE_SELL) // Verifica se é venda
         posicionamento.volume -= vol;

      if(hora < posicionamento.hora || posicionamento.hora == 0) // Verificando se última posição, se hoiuver mais de uma em conta hedge
        {         // Atribuindo valores as variaveis
         posicionamento.ticket = ticket; 
         posicionamento.price = PositionGetDouble(POSITION_PRICE_OPEN);
         posicionamento.sl = PositionGetDouble(POSITION_SL);
         posicionamento.tp = PositionGetDouble(POSITION_TP);
         posicionamento.hora = hora; // Confirmando que última posição
        }
     }

   return posicionamento;
  }
//+------------------------------------------------------------------+
//| Função Horário operacional                                       |
//+------------------------------------------------------------------+
bool horario_operacional(void)
  {
   if(in_usar_horario == false) // Verifica se está ou não habilitado o horário
      return true;

// Comparando hora e minutos de operações
   if(time_corrente.hour > time_inicio.hour || (time_corrente.hour == time_inicio.hour && time_corrente.min >= time_inicio.min))
      if(time_corrente.hour < time_parar.hour || (time_corrente.hour == time_parar.hour && time_corrente.min < time_parar.min))
         return true;

   return false;
  }
//+------------------------------------------------------------------+
//| Função Horário zeragem                                           |
//+------------------------------------------------------------------+
bool horario_zeragem(void)
  {
   if(in_usar_zerar == false) // Verifica se horário de zerar está habilitado
      return false;

// Comparando horário atual com horário de zeragem
   if(time_corrente.hour > time_zerar.hour || (time_corrente.hour == time_zerar.hour && time_corrente.min >= time_zerar.min))
      return true;

   return false;
  }
//+------------------------------------------------------------------+
//| Função de entrada                                                |
//+------------------------------------------------------------------+
bool sinal_entrada(void)
  {
   if(sinal_1() > 0 && sinal_2() > 0) // conferindo sinais para compra 1 e 2
      return enviar_compra(); // Chamando o envio da ordem de compra
   else
      if(sinal_1() < 0 && sinal_2() < 0) // conferindo sinais para venda 1 e 2
         return enviar_venda();// Chamando o envio da ordem de venda

   return false;
  }
//+------------------------------------------------------------------+
//| Sinal saída 1                                                    |
//+------------------------------------------------------------------+
int sinal_1(void)
  {
   double up[]; // Variável para receber a banda superior
   double dn[]; // Variável para receber a banda inferior

   ArraySetAsSeries(up,true); // Colocando como série, sendo a barra atual como 0
   ArraySetAsSeries(dn,true);
   ArrayResize(up,1); // Atribuindo o tamanho do array
   ArrayResize(dn,1);

   int qtd_up = CopyBuffer(handle,1,0,1,up); // Copiando dados do indicador para a variável
   int qtd_dn = CopyBuffer(handle,2,0,1,dn);

   if(qtd_up < 1) // Checa se copiou a quantidade solicitada
     {
      printf("Erro %d no cálculo do indicador banda superior",GetLastError());
      return 0;
     }

   if(qtd_dn < 1)
     {
      printf("Erro %d no cálculo do indicador banda inferior",GetLastError());
      return 0;
     }

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID); // Valor de referência
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   if(bid > up[0]) // Verifica se o preço está acima da banda superior
      return -1;

   if(ask < dn[0])// Verifica se o preço está abaixo da banda inferior
      return 1;

   return 0;
  }
//+------------------------------------------------------------------+
//| Sinal saída 2                                                    |
//+------------------------------------------------------------------+
int sinal_2(void)
  { // Também verificação de bandas, igual a anterior
   double up[]; // Idem sinal_1()
   double dn[];

   ArraySetAsSeries(up,true);
   ArraySetAsSeries(dn,true);
   ArrayResize(up,1);
   ArrayResize(dn,1);

   int qtd_up = CopyBuffer(handle2,0,0,1,up);
   int qtd_dn = CopyBuffer(handle2,1,0,1,dn);

   if(qtd_up < 1)
     {
      printf("Erro %d no cálculo do indicador envelope superior",GetLastError());
      return 0;
     }

   if(qtd_dn < 1)
     {
      printf("Erro %d no cálculo do indicador envelope inferior",GetLastError());
      return 0;
     }

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   if(bid > up[0])
      return -1;

   if(ask < dn[0])
      return 1;

   return 0;
  }
//+------------------------------------------------------------------+
//| Função de saída                                                  |
//+------------------------------------------------------------------+
bool sinal_saida(const double pos, const ulong ticket)
  {
   if(pos > 0.0) // Se comprado verifica saída
      if(saida_1() > 0) // Cruzou para cima, saída da compra
         return trade.PositionClose(ticket); // Envio do comando de fechar a posição

   if(pos < 0.0)// Se vendido verifica saída
      if(saida_1() < 0)// Cruzou para baixo, saída da venda
         return trade.PositionClose(ticket);

   return false;
  }
//+------------------------------------------------------------------+
//| Sinal de saída                                                   |
//+------------------------------------------------------------------+
int saida_1(void)
  {
   double m[]; // Armazena valores da banda central
   ArraySetAsSeries(m,true);
   ArrayResize(m,1);

   int qtd = CopyBuffer(handle,0,0,1,m);

   if(qtd < 1)
     {
      printf("Erro %d no cálculo do indicador banda central",GetLastError());
      return 0;
     }

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   if(bid > m[0]) // Se o preço estiver acima da média
      return 1;

   if(ask < m[0])// Se o preço estiver abaixo da média
      return -1;

   return 0;
  }
//+------------------------------------------------------------------+
//| Compras                                                          |
//+------------------------------------------------------------------+
bool enviar_compra(void)
  {
   ulong bilhete2; // Variável para o número da ordem de compra aguardando execu~ção
   if(checar_ordem(bilhete2) == false) // Checando se há envio de ordens repetidas
     {
      printf("Compra negada ordem %d aguardando execução!",bilhete2);
      return false;
     }

   double price = normalizar(SymbolInfoDouble(_Symbol,SYMBOL_ASK)); // Preço de referência normalizado
   double sl = (in_sl > 0) ? normalizar(price-(in_sl*_Point)) : 0.00; // Atribuindo valor de stoploss
   double tp = (in_tp > 0) ? normalizar(price+(in_tp*_Point)) : 0.00;// Atribuindo valor de take profit

   return trade.Buy(in_volume,_Symbol,price,sl,tp,"Compra Robô "+(string)in_magic); // envio da ordem de compra
  }
//+------------------------------------------------------------------+
//| Vendas                                                           |
//+------------------------------------------------------------------+
bool enviar_venda(void)
  { // Idem envio de compra()
   ulong bilhete2;
   if(checar_ordem(bilhete2) == false)
     {
      printf("Venda negada ordem %d aguardando execução!",bilhete2);
      return false;
     }

   double price = normalizar(SymbolInfoDouble(_Symbol,SYMBOL_BID));
   double sl = (in_sl > 0) ? normalizar(price+(in_sl*_Point)): 0.00;
   double tp = (in_tp > 0) ? normalizar(price-(in_tp*_Point)) : 0.00;

   return trade.Sell(in_volume,_Symbol,price,sl,tp,"Venda Robô "+(string)in_magic); // envio da ordem de venda
  }
//+------------------------------------------------------------------+
//| Função de zerar                                                  |
//+------------------------------------------------------------------+
void zeragem(void)
  { // Zerando todas as posções do ativo do expert
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i); // Selecionando o bilhete da posição
      PositionSelectByTicket(ticket);

      string ativo = PositionGetString(POSITION_SYMBOL);
      ulong magic = PositionGetInteger(POSITION_MAGIC);

      if(ativo != _Symbol)
         continue;

      if(magic != in_magic)
         continue;

      ENUM_POSITION_TYPE tipo = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double vol = PositionGetDouble(POSITION_VOLUME);

// Confere compra ou venda para exibir a mensagem apropriada
      if(tipo == POSITION_TYPE_BUY)
        {
         trade.PositionClose(ticket);
         printf("Encerrada posição comprada %d e volume %f do ativo %s",ticket,vol,ativo);
        }
      else
        {
         trade.PositionClose(ticket);
         printf("Encerrada posição vendida %d e volume %f do ativo %s",ticket,vol,ativo);
        }
     }
  }
  //+------------------------------------------------------------------+
//| Chaecar Ordens Repetidas                                         |
//+------------------------------------------------------------------+
bool checar_ordem(ulong &bilhete1)
  {
   bilhete1 = 0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      ulong ticket = OrderGetTicket(i); // Selecionando o bilhete da da ordem
      if(OrderSelect(ticket) == false)
         continue;

      string ativo = OrderGetString(ORDER_SYMBOL);
      ulong magic = OrderGetInteger(ORDER_MAGIC);

      if(ativo != _Symbol) // Filtro apenas pelo ativo e não para o robô
         continue;

      ENUM_ORDER_TYPE tipo = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(tipo == ORDER_TYPE_BUY || tipo == ORDER_TYPE_SELL) // Confirma que há ordem a mercado aguardando execução
        {
         bilhete1 = ticket;
         return false;
        }
     }

   return true;
  }
//+------------------------------------------------------------------+
//| Verificar Permissões da conta                                    |
//+------------------------------------------------------------------+
bool checar_permissao()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) // Permissão para robô opear no terminal
      return false;

   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) // Verifica conexão com a internet e corretora
     {
      printf("Sem conexão com servidor");
      return false;
     }

   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) // Se a conta está habilitada pela corretora para operar
     {
      printf("Conta desabilitada para algo trading");
      return false;
     }

   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) // Verifica se pode utilizar robô nesta conta
     {
      printf("Não permitido robô nesta conta");
      return false;
     }

   return true;
  }
//+------------------------------------------------------------------+
//| Normalizar Preço                                                 |
//+------------------------------------------------------------------+
double normalizar(const double price)
  {
   double m_tick_size = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); // Tamanho da mudança mínima de preço

   if(m_tick_size != 0.0) // Verifica o ajuste
      return(NormalizeDouble(MathRound(price/m_tick_size)*m_tick_size,_Digits));

   return(NormalizeDouble(price,_Digits));
  }
//+------------------------------------------------------------------+
