SELECT uf, ano, vitimas, meses_informados
FROM "{database}"."{table}"
WHERE ano = {year}
ORDER BY uf;
