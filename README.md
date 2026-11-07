# Fire TV Menu Bar

Controle o Fire TV Stick a partir da barra de menu do macOS, usando ADB pela rede Wi-Fi.

## Pré-requisitos

1. Modo desenvolvedor ativo na TV: Configurações → Meu Fire TV → Sobre, selecione o nome do aparelho e aperte OK ~7 vezes. Depois, em Opções do desenvolvedor, ative **ADB debugging**.
2. ADB instalado no Mac: `brew install android-platform-tools`
3. Python 3 e as dependências:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Configuração

Copie o arquivo de exemplo e preencha o IP da TV:

```bash
cp config.example.json config.json
```

O `config.json` fica fora do Git (está no `.gitignore`), então o IP da sua rede não sobe para o repositório. Os nomes de pacote dos apps em `apps` podem ser trocados por qualquer outro.

## Uso

```bash
source .venv/bin/activate
python main.py
```

Um ícone de TV aparece na barra de menu. Os botões enviam comandos de controle remoto para a TV, e o item "Apps" abre os aplicativos configurados.

## Observações

- O ADB fica aberto na rede local. Desative a depuração na TV quando não estiver usando.
- Se o IP da TV mudar, reserve um IP fixo no roteador.
