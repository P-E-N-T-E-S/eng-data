SELECT ano, COUNT(*) AS linhas
FROM "{database}"."{table}"
WHERE ano = {year}
GROUP BY ano;
