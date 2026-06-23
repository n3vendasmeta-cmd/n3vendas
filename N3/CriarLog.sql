File.AppendAllText("nome.log", DateTime.Now + " - Entrou no gaveta" + Environment.NewLine);


//Método genérico de log
        public void LogGenericoN3(string message)
        {
            var logFilePath = Path.Combine(Environment.CurrentDirectory, "LogN3SO661231-km-percorrido.txt"); //alterar nome para o log que está sendo criado no momento
            try
            {
                using (StreamWriter writer = new StreamWriter(logFilePath, true))
                {
                    string logEntry = $"{DateTime.Now} - {message}";
                    writer.WriteLine(logEntry);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Erro ao registrar o log: {ex.Message}");
            }
        }
