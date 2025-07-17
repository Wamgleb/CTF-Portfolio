import tensorflow as tf

# Создание простой модели
model = tf.keras.Sequential([
    tf.keras.Input(shape=(1,)),
    tf.keras.layers.Dense(1)
])

# Сохранение модели в файл
model.save('clean_model.h5')

