Caros tive um problema com a linha de terra. Precisava de fazer figuras com uma linha de terra para resultados no Golfo de Cadiz. 
A solu��o que encontrei foi ler a linha de terra de alta resolu��o do GMT (http://gmt.soest.hawaii.edu/) e export�-la em formatos que os programas de gr�ficos percebessem. 
Actualmente existe a hip�tese de exportar dois tipos de formatos:
1 - Surfer (.bln)
2 - MohidGis (.lin)

T�m que correr apenas o batch pscoasttoAscii.bat. O programa n�o est� muito userfriendly mas d� para desenrascar. Tem que se ter instalado o GMT no computador. O pessoal do maretec de cima que quiser instalar o GMT no seu pc fale com o Rodrigo. Ele j� instalou no dele. O pessoal c� de baixo fale comigo.
S� para terem uma ideia do poder desta linha de terra vejam dois exemplos que envio em anexo um em surfer (teste.jpg) e outro em mohidgis (testegis.jpg).

Aqui vai um pequeno manual :

Fazer extract do ficheiro zip gmt.zip e por tudo na mesma directoria.

Abrir o batch pscoasttoAscii.bat

pscoast -R-12/-3/33/39 -M -W -Df > CadizGulf.gmt
FromASCIIGMTtoBNL.exe < data.dat

Alterar a janela de output :
a flag -R define a janela -Rlong_min/long_max/lat_min/lat_max

	O nome do ficheiro ASCII de output  do GMT aparece no final da 1� linha de comando 

	Alterar o formato de sa�da:
		Abrir o ficheiro data.dat

CadizGulf.gmt
CadizGulf.lin
2

		            O primeiro nome corresponde ao ficheiro ASCII de output do GMT j� referido em cima. Caso o seu nome seja alterado tem que ser alterado tamb�m aqui.
			O segundo nome � o ficheiro final de output no formato desejado por n�s.
			Na terceira linha � definido o tipo de output :1 - Surfer (.bln), 2 - MohidGis (.lin).

Correr o batch pscoasttoAscii.bat e j� est�. 


Um abra�o,
Paulo
