SELECT uf, ano,
       SUM(total_vitima) AS vitimas,
       COUNT(DISTINCT CASE WHEN total_vitima IS NOT NULL THEN mes END) AS meses_informados
FROM "{database}"."{table}"
WHERE ano = {year}
  AND evento = 'Homicídio doloso'
  AND abrangencia = 'Estadual'
GROUP BY uf, ano
ORDER BY uf
